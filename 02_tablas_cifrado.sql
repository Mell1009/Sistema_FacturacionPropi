-- ============================================================================
-- ARCHIVO: 02_tablas_y_cifrado.sql
-- DESCRIPCIÓN: Llaves de cifrado (REQ 006) y creación de tablas del sistema.
-- ============================================================================

USE DB_Propi_Facturacion;
GO

-- ----------------------------------------------------------------------------
-- 1. INFRAESTRUCTURA DE CIFRADO COLUMNAR (REQ 006)
-- ----------------------------------------------------------------------------
-- Crear Master Key y Certificate para la gestión de llaves de cifrado
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name LIKE '%DatabaseMasterKey%')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'PasswordSeguroPropi2026!';
END
GO

IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'Cert_Propi_DatosSensibles')
BEGIN
    CREATE CERTIFICATE Cert_Propi_DatosSensibles
    WITH SUBJECT = 'Certificado de Cifrado de Datos Sensibles de Clientes Propi';
END
GO

IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'SymKey_Propi_Clientes')
BEGIN
    CREATE SYMMETRIC KEY SymKey_Propi_Clientes
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE Cert_Propi_DatosSensibles;
END
GO

-- ----------------------------------------------------------------------------
-- 2. TABLAS DEL SISTEMA (REQ 001)
-- ----------------------------------------------------------------------------

-- Tabla: TiposImpuesto
CREATE TABLE dbo.TiposImpuesto (
    cod_impuesto INT IDENTITY(1,1) CONSTRAINT PK_TiposImpuesto PRIMARY KEY,
    cod_codigo VARCHAR(10) NOT NULL CONSTRAINT UQ_TiposImpuesto_Codigo UNIQUE,
    des_impuesto VARCHAR(100) NOT NULL,
    num_porcentaje DECIMAL(5,2) NOT NULL,
    num_tarifa DECIMAL(5,2) NOT NULL,
    ind_estado CHAR(1) NOT NULL CONSTRAINT DF_TiposImpuesto_Estado DEFAULT 'A' CONSTRAINT CK_TiposImpuesto_Estado CHECK (ind_estado IN ('A', 'I'))
);
GO

-- Tabla: Clientes (REQ 006: Campos sensibles cifrados en VARBINARY)
CREATE TABLE dbo.Clientes (
    cod_cliente INT IDENTITY(1,1) CONSTRAINT PK_Clientes PRIMARY KEY,
    nom_cliente VARCHAR(150) NOT NULL,
    tip_identificacion VARCHAR(20) NOT NULL CONSTRAINT CK_Clientes_TipId CHECK (tip_identificacion IN ('FISICA', 'JURIDICA', 'DIMEX', 'NITE')),
    
    -- Campos cifrados mediante Cell-Level Encryption (VARBINARY(256))
    num_identificacion_enc VARBINARY(256) NOT NULL,
    des_correo_enc VARBINARY(256) NOT NULL,
    num_telefono_enc VARBINARY(256) NOT NULL,
    
    -- Campos de dirección y actividad
    des_provincia VARCHAR(50) NOT NULL,
    des_canton VARCHAR(50) NOT NULL,
    des_distrito VARCHAR(50) NOT NULL,
    des_barrio VARCHAR(50) NULL,
    des_profesion VARCHAR(100) NULL,
    des_actividad_economica VARCHAR(150) NOT NULL,
    
    fec_registro DATETIME NOT NULL CONSTRAINT DF_Clientes_FecRegistro DEFAULT GETDATE(),
    ind_estado CHAR(1) NOT NULL CONSTRAINT DF_Clientes_Estado DEFAULT 'A' CONSTRAINT CK_Clientes_Estado CHECK (ind_estado IN ('A', 'I'))
);
GO

-- Tabla: ProductosServicios
CREATE TABLE dbo.ProductosServicios (
    cod_producto INT IDENTITY(1,1) CONSTRAINT PK_ProductosServicios PRIMARY KEY,
    cod_cabys VARCHAR(20) NOT NULL,
    des_producto VARCHAR(200) NOT NULL,
    cod_unidad_medida VARCHAR(10) NOT NULL,
    num_precio DECIMAL(18,2) NOT NULL CONSTRAINT CK_Productos_Precio CHECK (num_precio >= 0),
    cod_impuesto INT NOT NULL CONSTRAINT FK_Productos_TiposImpuesto FOREIGN KEY REFERENCES dbo.TiposImpuesto(cod_impuesto),
    ind_estado CHAR(1) NOT NULL CONSTRAINT DF_Productos_Estado DEFAULT 'A' CONSTRAINT CK_Productos_Estado CHECK (ind_estado IN ('A', 'I'))
);
GO

-- Tabla: Facturas
CREATE TABLE dbo.Facturas (
    cod_factura INT IDENTITY(1,1) CONSTRAINT PK_Facturas PRIMARY KEY,
    cod_cliente INT NOT NULL CONSTRAINT FK_Facturas_Clientes FOREIGN KEY REFERENCES dbo.Clientes(cod_cliente),
    fec_factura DATETIME NOT NULL CONSTRAINT DF_Facturas_Fecha DEFAULT GETDATE(),
    ind_condicion_venta VARCHAR(20) NOT NULL CONSTRAINT CK_Facturas_Condicion CHECK (ind_condicion_venta IN ('CONTADO', 'CREDITO')),
    ind_medio_pago VARCHAR(30) NOT NULL CONSTRAINT CK_Facturas_MedioPago CHECK (ind_medio_pago IN ('EFECTIVO', 'TARJETA', 'CHEQUE', 'TRANSFERENCIA', 'SINPE_MOVIL', 'OTROS')),
    cod_moneda CHAR(3) NOT NULL CONSTRAINT DF_Facturas_Moneda DEFAULT 'CRC' CONSTRAINT CK_Facturas_Moneda CHECK (cod_moneda IN ('CRC', 'USD')),
    num_tipo_cambio DECIMAL(10,4) NOT NULL CONSTRAINT DF_Facturas_TipoCambio DEFAULT 1.0000,
    des_observaciones VARCHAR(500) NULL,
    num_subtotal DECIMAL(18,2) NOT NULL,
    num_total_impuestos DECIMAL(18,2) NOT NULL,
    num_monto_total DECIMAL(18,2) NOT NULL
);
GO

-- Tabla: FacturasDetalle
CREATE TABLE dbo.FacturasDetalle (
    cod_detalle INT IDENTITY(1,1) CONSTRAINT PK_FacturasDetalle PRIMARY KEY,
    cod_factura INT NOT NULL CONSTRAINT FK_FacturasDetalle_Facturas FOREIGN KEY REFERENCES dbo.Facturas(cod_factura),
    cod_producto INT NOT NULL CONSTRAINT FK_FacturasDetalle_Productos FOREIGN KEY REFERENCES dbo.ProductosServicios(cod_producto),
    num_cantidad DECIMAL(12,2) NOT NULL CONSTRAINT CK_Detalle_Cantidad CHECK (num_cantidad > 0),
    num_monto_linea DECIMAL(18,2) NOT NULL
);
GO

-- Tabla: NotasCreditoDebito
CREATE TABLE dbo.NotasCreditoDebito (
    cod_nota INT IDENTITY(1,1) CONSTRAINT PK_NotasCreditoDebito PRIMARY KEY,
    fec_nota DATETIME NOT NULL CONSTRAINT DF_Notas_Fecha DEFAULT GETDATE(),
    cod_factura INT NOT NULL CONSTRAINT FK_Notas_Facturas FOREIGN KEY REFERENCES dbo.Facturas(cod_factura),
    ind_tipo VARCHAR(10) NOT NULL CONSTRAINT CK_Notas_Tipo CHECK (ind_tipo IN ('CREDITO', 'DEBITO')),
    des_motivo VARCHAR(250) NOT NULL,
    num_monto DECIMAL(18,2) NOT NULL
);
GO