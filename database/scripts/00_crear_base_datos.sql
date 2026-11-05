/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Curso    : IF-0010 Bases de Datos II - UCR, Recinto de Paraíso (G22)
   Script   : 00_crear_base_datos.sql
   Propósito: Crea la base de datos PropiFacturacion (idempotente) y deja
              configuradas las opciones que exige el resto del proyecto.
   Notas    : - Usa la ruta de datos/log por defecto de CADA instancia, así
                funciona igual en la máquina de ambos integrantes.
              - No borra nada. Para empezar de cero usar tools/reset_local.sql
   ===================================================================== */
USE master;
GO

IF DB_ID(N'PropiFacturacion') IS NULL
BEGIN
    DECLARE @ruta_datos NVARCHAR(512) = CONVERT(NVARCHAR(512), SERVERPROPERTY('InstanceDefaultDataPath'));
    DECLARE @ruta_log   NVARCHAR(512) = CONVERT(NVARCHAR(512), SERVERPROPERTY('InstanceDefaultLogPath'));
    DECLARE @sql        NVARCHAR(MAX);

    SET @sql = N'CREATE DATABASE PropiFacturacion
        ON PRIMARY
        (
            NAME       = N''PropiFacturacion_data'',
            FILENAME   = N''' + @ruta_datos + N'PropiFacturacion.mdf'',
            SIZE       = 128MB,
            FILEGROWTH = 64MB
        )
        LOG ON
        (
            NAME       = N''PropiFacturacion_log'',
            FILENAME   = N''' + @ruta_log + N'PropiFacturacion_log.ldf'',
            SIZE       = 64MB,
            FILEGROWTH = 64MB
        );';

    EXEC (@sql);
    PRINT 'Base de datos PropiFacturacion creada.';
END
ELSE
    PRINT 'La base de datos PropiFacturacion ya existe (se conserva).';
GO

/* ---------------------------------------------------------------------
   Opciones de la base de datos
   --------------------------------------------------------------------- */

-- Nivel de compatibilidad de SQL Server 2022
ALTER DATABASE PropiFacturacion SET COMPATIBILITY_LEVEL = 160;
GO

-- Modelo de recuperación FULL: requerido por la política de respaldos (REQ 013),
-- backups de log y la réplica / log shipping (REQ 014).
-- OJO: la cadena de log solo empieza a funcionar tras el primer BACKUP FULL.
ALTER DATABASE PropiFacturacion SET RECOVERY FULL;
GO

-- Aislamiento de lectura por versiones (justificación en REQ 007):
-- las lecturas de reportes no bloquean a las escrituras de facturación.
IF EXISTS (SELECT 1 FROM sys.databases
           WHERE name = N'PropiFacturacion'
             AND (is_read_committed_snapshot_on = 0 OR snapshot_isolation_state = 0))
BEGIN
    -- ROLLBACK IMMEDIATE cierra otras conexiones abiertas a la BD (solo entorno local).
    ALTER DATABASE PropiFacturacion SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
    ALTER DATABASE PropiFacturacion SET ALLOW_SNAPSHOT_ISOLATION ON;
END
GO

ALTER DATABASE PropiFacturacion SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE PropiFacturacion SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE PropiFacturacion SET PAGE_VERIFY CHECKSUM;
GO

PRINT '00_crear_base_datos.sql finalizado.';
GO
