/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Script   : 05_procedimientos_crud.sql
   Propósito: Toda la lógica de acceso a datos de la aplicación (REQ 002),
              login/logout (REQ 003) y cifrado columnar (REQ 006).
              La app SOLO ejecuta estos procedimientos (sin SQL dinámico ni
              concatenado -> sin SQL Injection).
   Idempotente: CREATE OR ALTER.

   Convenciones
     - Esquema app (dueño dbo). Los usuarios solo reciben EXECUTE (ver 07).
     - WITH EXECUTE AS OWNER: permite abrir la clave simétrica sin darle
       permisos sobre el certificado a los usuarios. ORIGINAL_LOGIN() sigue
       devolviendo el login real, así que la auditoría no se contamina.
     - Todos usan TRY...CATCH; los que modifican datos usan transacción.
     - Errores de negocio: THROW 50001+ con mensaje legible para el frontend.
   Códigos de error propios
     50001 identificación vacía        50002 identificación duplicada
     50003 registro con dependencias   50004 registro no encontrado
     50010 factura sin líneas          50011 cliente inexistente/inactivo
     50012 producto inexistente/inactivo
   ===================================================================== */
USE PropiFacturacion;
GO
SET NOCOUNT ON;
GO

IF SCHEMA_ID(N'app') IS NULL EXEC (N'CREATE SCHEMA app AUTHORIZATION dbo;');
GO

-- Tipo de tabla para enviar el detalle de una factura en una sola llamada
IF TYPE_ID(N'app.TD_FacturaDetalle') IS NULL
    CREATE TYPE app.TD_FacturaDetalle AS TABLE
    (
        cod_producto INT           NOT NULL,
        num_cantidad DECIMAL(12,2) NOT NULL CHECK (num_cantidad > 0)
    );
GO

/* =====================================================================
   ACCESO (REQ 003)
   La app abre la conexión con el login/clave del usuario y llama a
   usp_Acceso_Registrar. Eso inserta en seg.BitacoraAcceso y deja el
   id de acceso en SESSION_CONTEXT('cod_sesion'), que leen los triggers.
   OJO con el pool de conexiones: sp_reset_connection borra el
   SESSION_CONTEXT; la app debe mantener su conexión abierta o volver a
   llamar a este procedimiento al reutilizarla.
   ===================================================================== */
CREATE OR ALTER PROCEDURE app.usp_Acceso_Registrar
    @nom_terminal VARCHAR(128) = NULL,   -- la app puede enviar Environment.MachineName
    @dir_ip       VARCHAR(45)  = NULL,   -- ... y su IP; si no, se toma del servidor
    @cod_acceso   INT          = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @sesion NVARCHAR(64);

        INSERT INTO seg.BitacoraAcceso (nom_usuario, nom_terminal, dir_ip)
        VALUES (ORIGINAL_LOGIN(),
                ISNULL(@nom_terminal, HOST_NAME()),
                ISNULL(@dir_ip, ISNULL(CONVERT(VARCHAR(45), CONNECTIONPROPERTY('client_net_address')), '(local)')));

        SET @cod_acceso = SCOPE_IDENTITY();
        SET @sesion     = CONVERT(NVARCHAR(64), @cod_acceso);
        EXEC sys.sp_set_session_context @key = N'cod_sesion', @value = @sesion;

        SELECT @cod_acceso AS cod_acceso;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Acceso_Cerrar
    @cod_acceso INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        UPDATE seg.BitacoraAcceso
           SET fec_salida = GETDATE()
         WHERE cod_acceso  = @cod_acceso
           AND nom_usuario = ORIGINAL_LOGIN()   -- cada quien cierra solo su sesión
           AND fec_salida IS NULL;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* =====================================================================
   CATÁLOGO: TIPO DE IDENTIFICACIÓN
   ===================================================================== */
CREATE OR ALTER PROCEDURE app.usp_TipoIdentificacion_Listar
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT cod_tipo_identificacion, des_tipo_identificacion, ind_estado
        FROM fact.TipoIdentificacion
        WHERE ind_estado = 'A'
        ORDER BY cod_tipo_identificacion;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* =====================================================================
   TIPO DE IMPUESTO
   ===================================================================== */
CREATE OR ALTER PROCEDURE app.usp_TipoImpuesto_Insertar
    @cod_impuesto VARCHAR(10),
    @des_impuesto VARCHAR(100),
    @por_impuesto DECIMAL(5,2),
    @mon_tarifa   DECIMAL(18,2) = 0,
    @cod_tipo_impuesto INT = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO fact.TipoImpuesto (cod_impuesto, des_impuesto, por_impuesto, mon_tarifa)
        VALUES (@cod_impuesto, @des_impuesto, @por_impuesto, @mon_tarifa);
        SET @cod_tipo_impuesto = SCOPE_IDENTITY();
        COMMIT;
        SELECT @cod_tipo_impuesto AS cod_tipo_impuesto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_TipoImpuesto_Actualizar
    @cod_tipo_impuesto INT,
    @cod_impuesto VARCHAR(10),
    @des_impuesto VARCHAR(100),
    @por_impuesto DECIMAL(5,2),
    @mon_tarifa   DECIMAL(18,2),
    @ind_estado   CHAR(1)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE fact.TipoImpuesto
           SET cod_impuesto = @cod_impuesto, des_impuesto = @des_impuesto,
               por_impuesto = @por_impuesto, mon_tarifa   = @mon_tarifa,
               ind_estado   = @ind_estado
         WHERE cod_tipo_impuesto = @cod_tipo_impuesto;
        IF @@ROWCOUNT = 0 THROW 50004, N'El tipo de impuesto no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_TipoImpuesto_Eliminar
    @cod_tipo_impuesto INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM fact.TipoImpuesto WHERE cod_tipo_impuesto = @cod_tipo_impuesto;
        IF @@ROWCOUNT = 0 THROW 50004, N'El tipo de impuesto no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        DECLARE @n INT = ERROR_NUMBER();
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF @n = 547 THROW 50003, N'No se puede eliminar: hay productos con este impuesto. Inactívelo en su lugar.', 1;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_TipoImpuesto_Obtener
    @cod_tipo_impuesto INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT cod_tipo_impuesto, cod_impuesto, des_impuesto, por_impuesto, mon_tarifa, ind_estado
        FROM fact.TipoImpuesto WHERE cod_tipo_impuesto = @cod_tipo_impuesto;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_TipoImpuesto_Listar
    @ind_estado CHAR(1) = NULL      -- NULL = todos
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT cod_tipo_impuesto, cod_impuesto, des_impuesto, por_impuesto, mon_tarifa, ind_estado
        FROM fact.TipoImpuesto
        WHERE @ind_estado IS NULL OR ind_estado = @ind_estado
        ORDER BY cod_impuesto;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* =====================================================================
   PRODUCTO / SERVICIO
   ===================================================================== */
CREATE OR ALTER PROCEDURE app.usp_Producto_Insertar
    @cod_cabys         VARCHAR(13),
    @des_producto      VARCHAR(200),
    @des_unidad_medida VARCHAR(20),
    @mon_precio        DECIMAL(18,2),
    @cod_tipo_impuesto INT,
    @cod_producto      INT = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO fact.Producto (cod_cabys, des_producto, des_unidad_medida, mon_precio, cod_tipo_impuesto)
        VALUES (@cod_cabys, @des_producto, @des_unidad_medida, @mon_precio, @cod_tipo_impuesto);
        SET @cod_producto = SCOPE_IDENTITY();
        COMMIT;
        SELECT @cod_producto AS cod_producto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Producto_Actualizar
    @cod_producto      INT,
    @cod_cabys         VARCHAR(13),
    @des_producto      VARCHAR(200),
    @des_unidad_medida VARCHAR(20),
    @mon_precio        DECIMAL(18,2),
    @cod_tipo_impuesto INT,
    @ind_estado        CHAR(1)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE fact.Producto
           SET cod_cabys = @cod_cabys, des_producto = @des_producto,
               des_unidad_medida = @des_unidad_medida, mon_precio = @mon_precio,
               cod_tipo_impuesto = @cod_tipo_impuesto, ind_estado = @ind_estado
         WHERE cod_producto = @cod_producto;
        IF @@ROWCOUNT = 0 THROW 50004, N'El producto no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Producto_Eliminar
    @cod_producto INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM fact.Producto WHERE cod_producto = @cod_producto;
        IF @@ROWCOUNT = 0 THROW 50004, N'El producto no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        DECLARE @n INT = ERROR_NUMBER();
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF @n = 547 THROW 50003, N'No se puede eliminar: el producto ya fue facturado. Inactívelo en su lugar.', 1;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Producto_Obtener
    @cod_producto INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT p.cod_producto, p.cod_cabys, p.des_producto, p.des_unidad_medida, p.mon_precio,
               p.cod_tipo_impuesto, ti.cod_impuesto, ti.por_impuesto, p.ind_estado
        FROM fact.Producto p
        JOIN fact.TipoImpuesto ti ON ti.cod_tipo_impuesto = p.cod_tipo_impuesto
        WHERE p.cod_producto = @cod_producto;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Producto_Listar
    @ind_estado CHAR(1) = NULL      -- NULL = todos
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT p.cod_producto, p.cod_cabys, p.des_producto, p.des_unidad_medida, p.mon_precio,
               p.cod_tipo_impuesto, ti.cod_impuesto, ti.por_impuesto, p.ind_estado
        FROM fact.Producto p
        JOIN fact.TipoImpuesto ti ON ti.cod_tipo_impuesto = p.cod_tipo_impuesto
        WHERE @ind_estado IS NULL OR p.ind_estado = @ind_estado
        ORDER BY p.des_producto;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* =====================================================================
   CLIENTE  (REQ 006: identificación, correo y teléfono cifrados)
   hash_identificacion = SHA2_256( tipo + '|' + número normalizado )
   (normalizado = sin guiones ni espacios, en mayúscula)
   Los datos se descifran SOLO dentro de estos procedimientos.
   ===================================================================== */
CREATE OR ALTER PROCEDURE app.usp_Cliente_Insertar
    @nom_cliente             VARCHAR(150),
    @cod_tipo_identificacion TINYINT,
    @num_identificacion      VARCHAR(50),
    @nom_provincia           VARCHAR(50),
    @nom_canton              VARCHAR(50),
    @nom_distrito            VARCHAR(50),
    @nom_barrio              VARCHAR(80)  = NULL,
    @des_profesion           VARCHAR(100) = NULL,
    @des_actividad_economica VARCHAR(150) = NULL,
    @des_correo              VARCHAR(250),
    @num_telefono            VARCHAR(30)  = NULL,
    @cod_cliente             INT          = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @norm VARCHAR(50) = UPPER(REPLACE(REPLACE(LTRIM(RTRIM(@num_identificacion)), '-', ''), ' ', ''));
    DECLARE @hash VARBINARY(32);
    BEGIN TRY
        IF @norm = '' THROW 50001, N'El número de identificación es obligatorio.', 1;
        SET @hash = HASHBYTES('SHA2_256', CONCAT(@cod_tipo_identificacion, '|', @norm));
        IF EXISTS (SELECT 1 FROM fact.Cliente WHERE hash_identificacion = @hash)
            THROW 50002, N'Ya existe un cliente con esa identificación.', 1;

        OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;
        BEGIN TRAN;
        INSERT INTO fact.Cliente
            (nom_cliente, cod_tipo_identificacion, num_identificacion_cif, hash_identificacion,
             nom_provincia, nom_canton, nom_distrito, nom_barrio, des_profesion, des_actividad_economica,
             des_correo_cif, num_telefono_cif)
        VALUES
            (@nom_cliente, @cod_tipo_identificacion,
             ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(150), @num_identificacion)),
             @hash,
             @nom_provincia, @nom_canton, @nom_distrito, @nom_barrio, @des_profesion, @des_actividad_economica,
             ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(250), @des_correo)),
             CASE WHEN @num_telefono IS NULL THEN NULL
                  ELSE ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(150), @num_telefono)) END);
        SET @cod_cliente = SCOPE_IDENTITY();
        COMMIT;
        CLOSE SYMMETRIC KEY sk_Propi_Datos;

        SELECT @cod_cliente AS cod_cliente;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'sk_Propi_Datos')
            CLOSE SYMMETRIC KEY sk_Propi_Datos;
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Cliente_Actualizar
    @cod_cliente             INT,
    @nom_cliente             VARCHAR(150),
    @cod_tipo_identificacion TINYINT,
    @num_identificacion      VARCHAR(50),
    @nom_provincia           VARCHAR(50),
    @nom_canton              VARCHAR(50),
    @nom_distrito            VARCHAR(50),
    @nom_barrio              VARCHAR(80)  = NULL,
    @des_profesion           VARCHAR(100) = NULL,
    @des_actividad_economica VARCHAR(150) = NULL,
    @des_correo              VARCHAR(250),
    @num_telefono            VARCHAR(30)  = NULL,
    @ind_estado              CHAR(1)      = 'A'
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @norm VARCHAR(50) = UPPER(REPLACE(REPLACE(LTRIM(RTRIM(@num_identificacion)), '-', ''), ' ', ''));
    DECLARE @hash VARBINARY(32);
    BEGIN TRY
        IF @norm = '' THROW 50001, N'El número de identificación es obligatorio.', 1;
        IF NOT EXISTS (SELECT 1 FROM fact.Cliente WHERE cod_cliente = @cod_cliente)
            THROW 50004, N'El cliente no existe.', 1;
        SET @hash = HASHBYTES('SHA2_256', CONCAT(@cod_tipo_identificacion, '|', @norm));
        IF EXISTS (SELECT 1 FROM fact.Cliente WHERE hash_identificacion = @hash AND cod_cliente <> @cod_cliente)
            THROW 50002, N'Ya existe otro cliente con esa identificación.', 1;

        OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;
        BEGIN TRAN;
        UPDATE fact.Cliente
           SET nom_cliente = @nom_cliente,
               cod_tipo_identificacion = @cod_tipo_identificacion,
               num_identificacion_cif  = ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(150), @num_identificacion)),
               hash_identificacion     = @hash,
               nom_provincia = @nom_provincia, nom_canton = @nom_canton, nom_distrito = @nom_distrito,
               nom_barrio = @nom_barrio, des_profesion = @des_profesion,
               des_actividad_economica = @des_actividad_economica,
               des_correo_cif   = ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(250), @des_correo)),
               num_telefono_cif = CASE WHEN @num_telefono IS NULL THEN NULL
                                       ELSE ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(150), @num_telefono)) END,
               ind_estado = @ind_estado
         WHERE cod_cliente = @cod_cliente;
        COMMIT;
        CLOSE SYMMETRIC KEY sk_Propi_Datos;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'sk_Propi_Datos')
            CLOSE SYMMETRIC KEY sk_Propi_Datos;
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Cliente_CambiarEstado
    @cod_cliente INT,
    @ind_estado  CHAR(1)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE fact.Cliente SET ind_estado = @ind_estado WHERE cod_cliente = @cod_cliente;
        IF @@ROWCOUNT = 0 THROW 50004, N'El cliente no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Cliente_Eliminar
    @cod_cliente INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM fact.Cliente WHERE cod_cliente = @cod_cliente;
        IF @@ROWCOUNT = 0 THROW 50004, N'El cliente no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        DECLARE @n INT = ERROR_NUMBER();
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF @n = 547 THROW 50003, N'No se puede eliminar: el cliente tiene facturas. Inactívelo en su lugar.', 1;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Cliente_Obtener
    @cod_cliente INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;
        SELECT c.cod_cliente, c.nom_cliente, c.cod_tipo_identificacion,
               CONVERT(VARCHAR(50),  DECRYPTBYKEY(c.num_identificacion_cif)) AS num_identificacion,
               c.nom_provincia, c.nom_canton, c.nom_distrito, c.nom_barrio,
               c.des_profesion, c.des_actividad_economica,
               CONVERT(VARCHAR(250), DECRYPTBYKEY(c.des_correo_cif))   AS des_correo,
               CONVERT(VARCHAR(30),  DECRYPTBYKEY(c.num_telefono_cif)) AS num_telefono,
               c.fec_registro, c.ind_estado
        FROM fact.Cliente c
        WHERE c.cod_cliente = @cod_cliente;
        CLOSE SYMMETRIC KEY sk_Propi_Datos;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'sk_Propi_Datos')
            CLOSE SYMMETRIC KEY sk_Propi_Datos;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Cliente_Listar
    @ind_estado CHAR(1) = NULL      -- NULL = todos
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;
        SELECT c.cod_cliente, c.nom_cliente, c.cod_tipo_identificacion,
               CONVERT(VARCHAR(50),  DECRYPTBYKEY(c.num_identificacion_cif)) AS num_identificacion,
               c.nom_provincia, c.nom_canton, c.nom_distrito,
               c.des_actividad_economica,
               CONVERT(VARCHAR(250), DECRYPTBYKEY(c.des_correo_cif))   AS des_correo,
               CONVERT(VARCHAR(30),  DECRYPTBYKEY(c.num_telefono_cif)) AS num_telefono,
               c.fec_registro, c.ind_estado
        FROM fact.Cliente c
        WHERE @ind_estado IS NULL OR c.ind_estado = @ind_estado
        ORDER BY c.nom_cliente;
        CLOSE SYMMETRIC KEY sk_Propi_Datos;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'sk_Propi_Datos')
            CLOSE SYMMETRIC KEY sk_Propi_Datos;
        THROW;
    END CATCH
END
GO

/* =====================================================================
   FACTURA
   El frontend envía encabezado + líneas (producto, cantidad). El servidor
   calcula montos con el precio e impuesto vigentes:
       mon_linea     = ROUND(cantidad * precio, 2)
       impuesto/línea= ROUND(mon_linea * por_impuesto / 100, 2)
   y deja el CHECK  total = subtotal + impuestos satisfecho.
   (Se asume que los precios del catálogo están en la moneda de la factura.)
   ===================================================================== */
CREATE OR ALTER PROCEDURE app.usp_Factura_Insertar
    @cod_cliente         INT,
    @ind_condicion_venta CHAR(1),
    @ind_medio_pago      CHAR(1),
    @cod_moneda          CHAR(3)       = 'CRC',
    @mon_tipo_cambio     DECIMAL(10,4) = 1,
    @des_observaciones   VARCHAR(500)  = NULL,
    @detalle             app.TD_FacturaDetalle READONLY,
    @num_factura         INT           = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM @detalle)
            THROW 50010, N'La factura debe tener al menos una línea.', 1;
        IF NOT EXISTS (SELECT 1 FROM fact.Cliente WHERE cod_cliente = @cod_cliente AND ind_estado = 'A')
            THROW 50011, N'El cliente no existe o está inactivo.', 1;
        IF EXISTS (SELECT 1
                   FROM @detalle d
                   LEFT JOIN fact.Producto p ON p.cod_producto = d.cod_producto AND p.ind_estado = 'A'
                   WHERE p.cod_producto IS NULL)
            THROW 50012, N'Hay productos inexistentes o inactivos en el detalle.', 1;

        BEGIN TRAN;

        INSERT INTO fact.Factura (cod_cliente, ind_condicion_venta, ind_medio_pago, cod_moneda, mon_tipo_cambio, des_observaciones)
        VALUES (@cod_cliente, @ind_condicion_venta, @ind_medio_pago, @cod_moneda, @mon_tipo_cambio, @des_observaciones);
        SET @num_factura = SCOPE_IDENTITY();

        ;WITH l AS
        (
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS num_linea,
                   d.cod_producto, d.num_cantidad,
                   CONVERT(DECIMAL(18,2), ROUND(d.num_cantidad * p.mon_precio, 2)) AS mon_linea
            FROM @detalle d
            JOIN fact.Producto p ON p.cod_producto = d.cod_producto
        )
        INSERT INTO fact.FacturaDetalle (num_factura, num_linea, cod_producto, num_cantidad, mon_linea)
        SELECT @num_factura, num_linea, cod_producto, num_cantidad, mon_linea FROM l;

        UPDATE f
           SET mon_subtotal        = t.sub,
               mon_total_impuestos = t.imp,
               mon_total           = t.sub + t.imp
        FROM fact.Factura f
        CROSS APPLY (SELECT SUM(d.mon_linea) AS sub,
                            SUM(CONVERT(DECIMAL(18,2), ROUND(d.mon_linea * ti.por_impuesto / 100.0, 2))) AS imp
                     FROM fact.FacturaDetalle d
                     JOIN fact.Producto p       ON p.cod_producto = d.cod_producto
                     JOIN fact.TipoImpuesto ti  ON ti.cod_tipo_impuesto = p.cod_tipo_impuesto
                     WHERE d.num_factura = f.num_factura) t
        WHERE f.num_factura = @num_factura;

        COMMIT;
        SELECT @num_factura AS num_factura;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Factura_Obtener
    @num_factura INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Resultado 1: encabezado
        SELECT f.num_factura, f.cod_cliente, c.nom_cliente, f.fec_factura,
               f.ind_condicion_venta, f.ind_medio_pago, f.cod_moneda, f.mon_tipo_cambio,
               f.des_observaciones, f.mon_subtotal, f.mon_total_impuestos, f.mon_total
        FROM fact.Factura f
        JOIN fact.Cliente c ON c.cod_cliente = f.cod_cliente
        WHERE f.num_factura = @num_factura;

        -- Resultado 2: detalle
        SELECT d.num_linea, d.cod_producto, p.cod_cabys, p.des_producto,
               d.num_cantidad, p.mon_precio, d.mon_linea
        FROM fact.FacturaDetalle d
        JOIN fact.Producto p ON p.cod_producto = d.cod_producto
        WHERE d.num_factura = @num_factura
        ORDER BY d.num_linea;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Factura_Listar
    @fec_desde DATE = NULL,
    @fec_hasta DATE = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT f.num_factura, f.cod_cliente, c.nom_cliente, f.fec_factura,
               f.ind_condicion_venta, f.ind_medio_pago, f.cod_moneda,
               f.mon_subtotal, f.mon_total_impuestos, f.mon_total
        FROM fact.Factura f
        JOIN fact.Cliente c ON c.cod_cliente = f.cod_cliente
        WHERE (@fec_desde IS NULL OR f.fec_factura >= @fec_desde)
          AND (@fec_hasta IS NULL OR f.fec_factura <  DATEADD(DAY, 1, @fec_hasta))
        ORDER BY f.fec_factura DESC, f.num_factura DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Factura_Eliminar
    @num_factura INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM fact.NotaCreditoDebito WHERE num_factura = @num_factura)
            THROW 50003, N'No se puede eliminar: la factura tiene notas de crédito/débito.', 1;
        BEGIN TRAN;
        DELETE FROM fact.FacturaDetalle WHERE num_factura = @num_factura;
        DELETE FROM fact.Factura        WHERE num_factura = @num_factura;
        IF @@ROWCOUNT = 0 THROW 50004, N'La factura no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* =====================================================================
   NOTAS DE CRÉDITO / DÉBITO
   ===================================================================== */
CREATE OR ALTER PROCEDURE app.usp_Nota_Insertar
    @num_factura INT,
    @ind_tipo    CHAR(1),
    @des_motivo  VARCHAR(300),
    @cod_nota    INT = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM fact.Factura WHERE num_factura = @num_factura)
            THROW 50004, N'La factura indicada no existe.', 1;
        BEGIN TRAN;
        INSERT INTO fact.NotaCreditoDebito (num_factura, ind_tipo, des_motivo)
        VALUES (@num_factura, @ind_tipo, @des_motivo);
        SET @cod_nota = SCOPE_IDENTITY();
        COMMIT;
        SELECT @cod_nota AS cod_nota;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Nota_Actualizar
    @cod_nota   INT,
    @ind_tipo   CHAR(1),
    @des_motivo VARCHAR(300)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE fact.NotaCreditoDebito SET ind_tipo = @ind_tipo, des_motivo = @des_motivo WHERE cod_nota = @cod_nota;
        IF @@ROWCOUNT = 0 THROW 50004, N'La nota no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Nota_Eliminar
    @cod_nota INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM fact.NotaCreditoDebito WHERE cod_nota = @cod_nota;
        IF @@ROWCOUNT = 0 THROW 50004, N'La nota no existe.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE app.usp_Nota_Listar
    @num_factura INT = NULL         -- NULL = todas
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT n.cod_nota, n.fec_nota, n.num_factura, n.ind_tipo, n.des_motivo
        FROM fact.NotaCreditoDebito n
        WHERE @num_factura IS NULL OR n.num_factura = @num_factura
        ORDER BY n.fec_nota DESC, n.cod_nota DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '05_procedimientos_crud.sql finalizado.';
GO
