/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Script   : 06_procedimientos_reportes.sql
   Propósito: Los 4 reportes del REQ 007, como procedimientos almacenados
              con TRY...CATCH, transacción y documentación técnica.
   Idempotente: CREATE OR ALTER.

   NIVEL DE AISLAMIENTO (justificación para REQ 007)
     Se usa SNAPSHOT (con READ_COMMITTED_SNAPSHOT también activo en la BD):
       + Los reportes leen una foto consistente de los datos al iniciar la
         transacción, sin lecturas sucias ni lecturas no repetibles.
       + No toman bloqueos compartidos: no frenan a quien factura ni son
         frenados por escrituras (lectores y escritores no se bloquean).
       - Costo: el almacén de versiones consume espacio en tempdb.
     Alternativas descartadas: READ UNCOMMITTED (lecturas sucias, inaceptable
     en facturación/auditoría) y SERIALIZABLE (bloqueos de rango innecesarios
     para reportes de solo lectura).

   Rendimiento: los filtros por fecha son SARGables
     (col >= @desde AND col < DATEADD(DAY,1,@hasta)), nunca CONVERT(col).
     Los índices que los aprovechan se crean en 08_indices.sql (REQ 009).

   Nota: la clave simétrica se abre ANTES de iniciar la transacción
   (el estado de la clave es de sesión, no transaccional).
   ===================================================================== */
USE PropiFacturacion;
GO
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1) Reporte de Clientes Resumido
   Entrada : @fec_desde, @fec_hasta (fecha de registro del cliente),
             @ind_estado  A = activos, I = inactivos, T = todos
   Salida  : nombre, identificación, actividad económica, correo, teléfono
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE app.usp_Reporte_ClientesResumido
    @fec_desde  DATE,
    @fec_hasta  DATE,
    @ind_estado CHAR(1) = 'T'
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
    BEGIN TRY
        IF @fec_desde > @fec_hasta THROW 50020, N'La fecha desde no puede ser mayor que la fecha hasta.', 1;
        IF @ind_estado NOT IN ('A', 'I', 'T') THROW 50021, N'Estado inválido. Use A, I o T (todos).', 1;

        OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;
        BEGIN TRAN;

        SELECT c.nom_cliente                                                AS nombre,
               CONVERT(VARCHAR(50),  DECRYPTBYKEY(c.num_identificacion_cif)) AS num_identificacion,
               c.des_actividad_economica                                    AS actividad_economica,
               CONVERT(VARCHAR(250), DECRYPTBYKEY(c.des_correo_cif))        AS correo,
               CONVERT(VARCHAR(30),  DECRYPTBYKEY(c.num_telefono_cif))      AS telefono
        FROM fact.Cliente c
        WHERE c.fec_registro >= @fec_desde
          AND c.fec_registro <  DATEADD(DAY, 1, @fec_hasta)
          AND (@ind_estado = 'T' OR c.ind_estado = @ind_estado)
        ORDER BY c.nom_cliente;

        COMMIT;
        CLOSE SYMMETRIC KEY sk_Propi_Datos;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'sk_Propi_Datos')
            CLOSE SYMMETRIC KEY sk_Propi_Datos;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   2) Reporte de Facturas
   Entrada : @fec_desde, @fec_hasta (fecha de la factura)
   Salida  : cliente, identificación, actividad, nº factura, fecha,
             subtotal, total impuestos, total
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE app.usp_Reporte_Facturas
    @fec_desde DATE,
    @fec_hasta DATE
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
    BEGIN TRY
        IF @fec_desde > @fec_hasta THROW 50020, N'La fecha desde no puede ser mayor que la fecha hasta.', 1;

        OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;
        BEGIN TRAN;

        SELECT c.nom_cliente                                                AS nombre_cliente,
               CONVERT(VARCHAR(50), DECRYPTBYKEY(c.num_identificacion_cif)) AS num_identificacion,
               c.des_actividad_economica                                    AS actividad_economica,
               f.num_factura,
               f.fec_factura                                                AS fecha,
               f.mon_subtotal                                               AS subtotal,
               f.mon_total_impuestos                                        AS total_impuestos,
               f.mon_total                                                  AS total_factura
        FROM fact.Factura f
        JOIN fact.Cliente c ON c.cod_cliente = f.cod_cliente
        WHERE f.fec_factura >= @fec_desde
          AND f.fec_factura <  DATEADD(DAY, 1, @fec_hasta)
        ORDER BY f.fec_factura, f.num_factura;

        COMMIT;
        CLOSE SYMMETRIC KEY sk_Propi_Datos;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'sk_Propi_Datos')
            CLOSE SYMMETRIC KEY sk_Propi_Datos;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   3) Reporte de Pistas de Auditoría
   Entrada : @fec_desde, @fec_hasta (fecha de registro en bitácora),
             @usuario  (NULL o vacío = todos)
   Salida  : fecha, acción, usuario, tabla, llave, datos afectados
             (en update, des_datos trae {"ANTES":{..},"DESPUES":{..}})
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE app.usp_Reporte_PistasAuditoria
    @fec_desde DATE,
    @fec_hasta DATE,
    @usuario   VARCHAR(128) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
    BEGIN TRY
        IF @fec_desde > @fec_hasta THROW 50020, N'La fecha desde no puede ser mayor que la fecha hasta.', 1;
        SET @usuario = NULLIF(LTRIM(RTRIM(@usuario)), '');

        BEGIN TRAN;

        SELECT a.fec_registro,
               CASE a.ind_accion WHEN 'I' THEN N'Inserción'
                                 WHEN 'D' THEN N'Borrado'
                                 WHEN 'U' THEN N'Modificación' END AS accion,
               a.cod_usuario  AS nombre_usuario,
               a.cod_tabla    AS tabla_afectada,
               a.cod_llave    AS llave_registro,
               a.des_datos    AS datos_afectados
        FROM aud.BitacoraAuditoria a
        WHERE a.fec_registro >= @fec_desde
          AND a.fec_registro <  DATEADD(DAY, 1, @fec_hasta)
          AND (@usuario IS NULL OR a.cod_usuario = @usuario)
        ORDER BY a.fec_registro DESC;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   4) Reporte de Configuración de Seguridad
   Entrada : @usuario (NULL o vacío = todos)
   Salida  : usuario, rol, objeto, tipo de objeto, permiso, estado
   Qué hace: une usuarios -> roles a los que pertenecen -> permisos del rol
             (y los permisos directos del usuario). Los permisos concedidos
             sobre un ESQUEMA se expanden a los objetos que contiene.
             estado_permiso = GRANT / DENY.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE app.usp_Reporte_ConfiguracionSeguridad
    @usuario SYSNAME = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
    BEGIN TRY
        SET @usuario = NULLIF(LTRIM(RTRIM(@usuario)), '');

        BEGIN TRAN;

        ;WITH usuarios AS
        (
            SELECT principal_id, name
            FROM sys.database_principals
            WHERE type IN ('S', 'U')                       -- usuarios SQL / Windows
              AND name NOT IN (N'dbo', N'guest', N'INFORMATION_SCHEMA', N'sys')
              AND (@usuario IS NULL OR name = @usuario)
        ),
        efectivos AS
        (
            SELECT u.name AS usuario, r.name AS rol, r.principal_id AS grantee_id
            FROM usuarios u
            JOIN sys.database_role_members m ON m.member_principal_id = u.principal_id
            JOIN sys.database_principals  r  ON r.principal_id = m.role_principal_id
            UNION ALL
            SELECT u.name, N'(permiso directo)', u.principal_id
            FROM usuarios u
        )
        SELECT e.usuario                                   AS nombre_usuario,
               e.rol                                       AS rol,
               o.name                                      AS nombre_objeto,
               SCHEMA_NAME(o.schema_id)                    AS esquema,
               CASE o.type WHEN 'U'  THEN N'Tabla'
                           WHEN 'P'  THEN N'Procedimiento'
                           WHEN 'V'  THEN N'Vista'
                           WHEN 'FN' THEN N'Función'
                           WHEN 'IF' THEN N'Función'
                           WHEN 'TF' THEN N'Función' END   AS tipo_objeto,
               CASE p.permission_name WHEN 'SELECT'  THEN N'Selección'
                                      WHEN 'INSERT'  THEN N'Inserción'
                                      WHEN 'DELETE'  THEN N'Borrado'
                                      WHEN 'UPDATE'  THEN N'Modificación'
                                      WHEN 'EXECUTE' THEN N'Execute' END AS tipo_permiso,
               p.state_desc                                AS estado_permiso
        FROM efectivos e
        JOIN sys.database_permissions p
              ON p.grantee_principal_id = e.grantee_id
             AND p.class IN (1, 3)                          -- 1 objeto, 3 esquema
             AND p.minor_id = 0
             AND p.permission_name IN ('SELECT', 'INSERT', 'DELETE', 'UPDATE', 'EXECUTE')
             AND p.state IN ('G', 'W', 'D')
        JOIN sys.objects o
              ON o.is_ms_shipped = 0
             AND o.type IN ('U', 'P', 'V', 'FN', 'IF', 'TF')
             AND ( (p.class = 1 AND o.object_id = p.major_id)
                OR (p.class = 3 AND o.schema_id = p.major_id) )
        ORDER BY e.usuario, e.rol, SCHEMA_NAME(o.schema_id), o.name, p.permission_name;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

PRINT '06_procedimientos_reportes.sql finalizado.';
GO
