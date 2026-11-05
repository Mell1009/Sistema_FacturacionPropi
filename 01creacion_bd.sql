-- ============================================================================
-- PROYECTO: Sistema de Gestión de Facturación - Proptech Propi
-- ARCHIVO: 01_creacion_bd.sql
-- DESCRIPCIÓN: Creación de la base de datos y configuración inicial.
-- ============================================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'DB_Propi_Facturacion')
BEGIN
    ALTER DATABASE DB_Propi_Facturacion SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DB_Propi_Facturacion;
END
GO

CREATE DATABASE DB_Propi_Facturacion;
GO

USE DB_Propi_Facturacion;
GO

-- Configuración recomendada para auditoría y compatibilidad JSON
ALTER DATABASE DB_Propi_Facturacion SET RECOVERY FULL;
GO