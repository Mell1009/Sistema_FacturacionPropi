/* =====================================================================
   reset_local.sql - BORRA la base PropiFacturacion de la instancia LOCAL.
   Úsalo solo en tu máquina cuando cambie la estructura de una tabla y
   quieras recrear todo con run_all.sql.
   ¡Se pierden todos los datos! (los datos de prueba se recargan con el script)
   ===================================================================== */
USE master;
GO
IF DB_ID(N'PropiFacturacion') IS NOT NULL
BEGIN
    ALTER DATABASE PropiFacturacion SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PropiFacturacion;
    PRINT 'Base de datos PropiFacturacion eliminada.';
END
ELSE
    PRINT 'No existía PropiFacturacion.';
GO
