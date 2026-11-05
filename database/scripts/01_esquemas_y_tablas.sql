/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Script   : 01_esquemas_y_tablas.sql
   Propósito: Crea esquemas y las 9 tablas del modelo (REQ 001).
              Incluye PK, FK, UNIQUE, DEFAULT y CHECK con nombre explícito.
   Idempotente: se puede ejecutar varias veces sin error.

   Esquemas
     fact : negocio (clientes, impuestos, productos, facturas, notas)
     seg  : seguridad (bitácora de acceso, REQ 003)
     aud  : auditoría (bitácora de cambios, REQ 005)

   Correcciones respecto al primer avance
     - Cliente.nom_provincia (antes cod_provincia en el diccionario).
     - BitacoraAuditoria.cod_guid: UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID().
     - BitacoraAuditoria.cod_usuario: VARCHAR (CHAR rellenaba con espacios).
     - BitacoraAuditoria.cod_sesion_usuario: VARCHAR(64) (SESSION_CONTEXT
       devuelve sql_variant; la app genera un identificador de sesión).
     - Factura: CHECK mon_total = mon_subtotal + mon_total_impuestos.
     - Producto.cod_cabys: CHECK de 13 dígitos numéricos.
   ===================================================================== */
USE PropiFacturacion;
GO
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   Esquemas
   --------------------------------------------------------------------- */
IF SCHEMA_ID(N'fact') IS NULL EXEC (N'CREATE SCHEMA fact AUTHORIZATION dbo;');
GO
IF SCHEMA_ID(N'seg')  IS NULL EXEC (N'CREATE SCHEMA seg AUTHORIZATION dbo;');
GO
IF SCHEMA_ID(N'aud')  IS NULL EXEC (N'CREATE SCHEMA aud AUTHORIZATION dbo;');
GO

/* ---------------------------------------------------------------------
   fact.TipoIdentificacion  (catálogo)
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'fact.TipoIdentificacion', N'U') IS NULL
BEGIN
    CREATE TABLE fact.TipoIdentificacion
    (
        cod_tipo_identificacion TINYINT     NOT NULL
            CONSTRAINT PK_TipoIdentificacion PRIMARY KEY,
        des_tipo_identificacion VARCHAR(50) NOT NULL
            CONSTRAINT UQ_TipoIdentificacion_des UNIQUE,
        ind_estado              CHAR(1)     NOT NULL
            CONSTRAINT DF_TipoIdentificacion_estado DEFAULT ('A')
            CONSTRAINT CK_TipoIdentificacion_estado CHECK (ind_estado IN ('A','I'))
    );
END
GO

/* ---------------------------------------------------------------------
   fact.Cliente
   Campos sensibles (REQ 006) se guardan cifrados como VARBINARY.
   hash_identificacion = SHA-256 de (tipo + '|' + número normalizado);
   permite garantizar unicidad y buscar sin descifrar.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'fact.Cliente', N'U') IS NULL
BEGIN
    CREATE TABLE fact.Cliente
    (
        cod_cliente              INT            NOT NULL IDENTITY(1,1)
            CONSTRAINT PK_Cliente PRIMARY KEY,
        nom_cliente              VARCHAR(150)   NOT NULL
            CONSTRAINT CK_Cliente_nombre CHECK (LEN(LTRIM(RTRIM(nom_cliente))) > 0),
        cod_tipo_identificacion  TINYINT        NOT NULL
            CONSTRAINT FK_Cliente_TipoIdentificacion
            FOREIGN KEY REFERENCES fact.TipoIdentificacion (cod_tipo_identificacion),
        num_identificacion_cif   VARBINARY(256) NOT NULL,
        hash_identificacion      VARBINARY(32)  NOT NULL
            CONSTRAINT UQ_Cliente_hash_identificacion UNIQUE,
        nom_provincia            VARCHAR(50)    NOT NULL,
        nom_canton               VARCHAR(50)    NOT NULL,
        nom_distrito             VARCHAR(50)    NOT NULL,
        nom_barrio               VARCHAR(80)    NULL,
        des_profesion            VARCHAR(100)   NULL,
        des_actividad_economica  VARCHAR(150)   NULL,
        des_correo_cif           VARBINARY(512) NOT NULL,
        num_telefono_cif         VARBINARY(256) NULL,
        fec_registro             DATETIME       NOT NULL
            CONSTRAINT DF_Cliente_fec_registro DEFAULT (GETDATE()),
        ind_estado               CHAR(1)        NOT NULL
            CONSTRAINT DF_Cliente_estado DEFAULT ('A')
            CONSTRAINT CK_Cliente_estado CHECK (ind_estado IN ('A','I'))
    );
END
GO

/* ---------------------------------------------------------------------
   fact.TipoImpuesto
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'fact.TipoImpuesto', N'U') IS NULL
BEGIN
    CREATE TABLE fact.TipoImpuesto
    (
        cod_tipo_impuesto INT           NOT NULL IDENTITY(1,1)
            CONSTRAINT PK_TipoImpuesto PRIMARY KEY,
        cod_impuesto      VARCHAR(10)   NOT NULL
            CONSTRAINT UQ_TipoImpuesto_cod UNIQUE,
        des_impuesto      VARCHAR(100)  NOT NULL,
        por_impuesto      DECIMAL(5,2)  NOT NULL
            CONSTRAINT CK_TipoImpuesto_porcentaje CHECK (por_impuesto BETWEEN 0 AND 100),
        mon_tarifa        DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_TipoImpuesto_tarifa DEFAULT (0)
            CONSTRAINT CK_TipoImpuesto_tarifa CHECK (mon_tarifa >= 0),
        ind_estado        CHAR(1)       NOT NULL
            CONSTRAINT DF_TipoImpuesto_estado DEFAULT ('A')
            CONSTRAINT CK_TipoImpuesto_estado CHECK (ind_estado IN ('A','I'))
    );
END
GO

/* ---------------------------------------------------------------------
   fact.Producto  (productos y servicios, código CABYS de 13 dígitos)
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'fact.Producto', N'U') IS NULL
BEGIN
    CREATE TABLE fact.Producto
    (
        cod_producto      INT           NOT NULL IDENTITY(1,1)
            CONSTRAINT PK_Producto PRIMARY KEY,
        cod_cabys         VARCHAR(13)   NOT NULL
            CONSTRAINT UQ_Producto_cabys UNIQUE
            CONSTRAINT CK_Producto_cabys CHECK (LEN(cod_cabys) = 13 AND cod_cabys NOT LIKE '%[^0-9]%'),
        des_producto      VARCHAR(200)  NOT NULL,
        des_unidad_medida VARCHAR(20)   NOT NULL,
        mon_precio        DECIMAL(18,2) NOT NULL
            CONSTRAINT CK_Producto_precio CHECK (mon_precio >= 0),
        cod_tipo_impuesto INT           NOT NULL
            CONSTRAINT FK_Producto_TipoImpuesto
            FOREIGN KEY REFERENCES fact.TipoImpuesto (cod_tipo_impuesto),
        ind_estado        CHAR(1)       NOT NULL
            CONSTRAINT DF_Producto_estado DEFAULT ('A')
            CONSTRAINT CK_Producto_estado CHECK (ind_estado IN ('A','I'))
    );
END
GO

/* ---------------------------------------------------------------------
   fact.Factura
   ind_condicion_venta : C contado, R crédito
   ind_medio_pago      : E efectivo, T tarjeta, Q cheque, F transferencia,
                         S SINPE móvil, O otros
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'fact.Factura', N'U') IS NULL
BEGIN
    CREATE TABLE fact.Factura
    (
        num_factura         INT            NOT NULL IDENTITY(1,1)
            CONSTRAINT PK_Factura PRIMARY KEY,
        cod_cliente         INT            NOT NULL
            CONSTRAINT FK_Factura_Cliente
            FOREIGN KEY REFERENCES fact.Cliente (cod_cliente),
        fec_factura         DATETIME       NOT NULL
            CONSTRAINT DF_Factura_fecha DEFAULT (GETDATE()),
        ind_condicion_venta CHAR(1)        NOT NULL
            CONSTRAINT CK_Factura_condicion CHECK (ind_condicion_venta IN ('C','R')),
        ind_medio_pago      CHAR(1)        NOT NULL
            CONSTRAINT CK_Factura_medio_pago CHECK (ind_medio_pago IN ('E','T','Q','F','S','O')),
        cod_moneda          CHAR(3)        NOT NULL
            CONSTRAINT DF_Factura_moneda DEFAULT ('CRC')
            CONSTRAINT CK_Factura_moneda CHECK (cod_moneda IN ('CRC','USD')),
        mon_tipo_cambio     DECIMAL(10,4)  NOT NULL
            CONSTRAINT DF_Factura_tipo_cambio DEFAULT (1)
            CONSTRAINT CK_Factura_tipo_cambio CHECK (mon_tipo_cambio > 0),
        des_observaciones   VARCHAR(500)   NULL,
        mon_subtotal        DECIMAL(18,2)  NOT NULL
            CONSTRAINT DF_Factura_subtotal DEFAULT (0)
            CONSTRAINT CK_Factura_subtotal CHECK (mon_subtotal >= 0),
        mon_total_impuestos DECIMAL(18,2)  NOT NULL
            CONSTRAINT DF_Factura_impuestos DEFAULT (0)
            CONSTRAINT CK_Factura_impuestos CHECK (mon_total_impuestos >= 0),
        mon_total           DECIMAL(18,2)  NOT NULL
            CONSTRAINT DF_Factura_total DEFAULT (0)
            CONSTRAINT CK_Factura_total_pos CHECK (mon_total >= 0),
        CONSTRAINT CK_Factura_total_suma CHECK (mon_total = mon_subtotal + mon_total_impuestos)
    );
END
GO

/* ---------------------------------------------------------------------
   fact.FacturaDetalle  (resuelve la relación N:M Factura - Producto)
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'fact.FacturaDetalle', N'U') IS NULL
BEGIN
    CREATE TABLE fact.FacturaDetalle
    (
        num_factura  INT           NOT NULL
            CONSTRAINT FK_FacturaDetalle_Factura
            FOREIGN KEY REFERENCES fact.Factura (num_factura),
        num_linea    INT           NOT NULL
            CONSTRAINT CK_FacturaDetalle_linea CHECK (num_linea > 0),
        cod_producto INT           NOT NULL
            CONSTRAINT FK_FacturaDetalle_Producto
            FOREIGN KEY REFERENCES fact.Producto (cod_producto),
        num_cantidad DECIMAL(12,2) NOT NULL
            CONSTRAINT CK_FacturaDetalle_cantidad CHECK (num_cantidad > 0),
        mon_linea    DECIMAL(18,2) NOT NULL
            CONSTRAINT CK_FacturaDetalle_monto CHECK (mon_linea >= 0),
        CONSTRAINT PK_FacturaDetalle PRIMARY KEY (num_factura, num_linea)
    );
END
GO

/* ---------------------------------------------------------------------
   fact.NotaCreditoDebito
   ind_tipo: C crédito, D débito
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'fact.NotaCreditoDebito', N'U') IS NULL
BEGIN
    CREATE TABLE fact.NotaCreditoDebito
    (
        cod_nota    INT          NOT NULL IDENTITY(1,1)
            CONSTRAINT PK_NotaCreditoDebito PRIMARY KEY,
        fec_nota    DATETIME     NOT NULL
            CONSTRAINT DF_NotaCreditoDebito_fecha DEFAULT (GETDATE()),
        num_factura INT          NOT NULL
            CONSTRAINT FK_NotaCreditoDebito_Factura
            FOREIGN KEY REFERENCES fact.Factura (num_factura),
        ind_tipo    CHAR(1)      NOT NULL
            CONSTRAINT CK_NotaCreditoDebito_tipo CHECK (ind_tipo IN ('C','D')),
        des_motivo  VARCHAR(300) NOT NULL
            CONSTRAINT CK_NotaCreditoDebito_motivo CHECK (LEN(LTRIM(RTRIM(des_motivo))) > 0)
    );
END
GO

/* ---------------------------------------------------------------------
   seg.BitacoraAcceso  (REQ 003)
   Sin FK a otras tablas: el registro debe sobrevivir a cualquier cambio.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'seg.BitacoraAcceso', N'U') IS NULL
BEGIN
    CREATE TABLE seg.BitacoraAcceso
    (
        cod_acceso   INT          NOT NULL IDENTITY(1,1)
            CONSTRAINT PK_BitacoraAcceso PRIMARY KEY,
        nom_usuario  VARCHAR(128) NOT NULL,
        nom_terminal VARCHAR(128) NOT NULL,
        dir_ip       VARCHAR(45)  NOT NULL,
        fec_ingreso  DATETIME     NOT NULL
            CONSTRAINT DF_BitacoraAcceso_ingreso DEFAULT (GETDATE()),
        fec_salida   DATETIME     NULL,
        fec_registro DATETIME     NOT NULL
            CONSTRAINT DF_BitacoraAcceso_registro DEFAULT (GETDATE()),
        CONSTRAINT CK_BitacoraAcceso_salida CHECK (fec_salida IS NULL OR fec_salida >= fec_ingreso)
    );
END
GO

/* ---------------------------------------------------------------------
   aud.BitacoraAuditoria  (REQ 005)
   - PK NONCLUSTERED sobre el GUID (aleatorio, mala llave de ordenamiento).
   - Índice CLUSTERED por fec_registro: el reporte filtra por rango de fechas.
   - Sin FK: la pista se conserva aunque se borre el dato original.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'aud.BitacoraAuditoria', N'U') IS NULL
BEGIN
    CREATE TABLE aud.BitacoraAuditoria
    (
        fec_registro       DATETIME         NOT NULL
            CONSTRAINT DF_BitacoraAuditoria_registro DEFAULT (GETDATE()),
        cod_guid           UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT DF_BitacoraAuditoria_guid DEFAULT (NEWID()),
        ind_accion         CHAR(1)          NOT NULL
            CONSTRAINT CK_BitacoraAuditoria_accion CHECK (ind_accion IN ('I','D','U')),
        cod_usuario        VARCHAR(128)     NOT NULL,
        cod_sesion_usuario VARCHAR(64)      NULL,
        cod_tabla          VARCHAR(255)     NOT NULL,
        cod_llave          VARCHAR(2000)    NULL,
        des_datos          VARCHAR(MAX)     NULL,
        CONSTRAINT PK_BitacoraAuditoria PRIMARY KEY NONCLUSTERED (cod_guid),
        INDEX CIX_BitacoraAuditoria_fec_registro CLUSTERED (fec_registro)
    );
END
GO

PRINT '01_esquemas_y_tablas.sql finalizado.';
GO
