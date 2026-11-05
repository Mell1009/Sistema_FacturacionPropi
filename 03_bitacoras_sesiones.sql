-- ============================================================================
-- ARCHIVO: 03_bitacoras_y_sesiones.sql
-- DESCRIPCIÓN: Tablas de auditoría de accesos (REQ 003) y bitácora de transacciones (REQ 005).
-- ============================================================================

USE DB_Propi_Facturacion;
GO

-- 1. Bitácora de Accesos/Login (REQ 003)
CREATE TABLE dbo.BitacoraAccesos (
    cod_acceso INT IDENTITY(1,1) CONSTRAINT PK_BitacoraAccesos PRIMARY KEY,
    nom_usuario VARCHAR(100) NOT NULL,
    nom_terminal VARCHAR(100) NOT NULL,
    dir_ip VARCHAR(45) NOT NULL,
    fec_ingreso DATETIME NOT NULL,
    fec_salida DATETIME NULL,
    fec_registro DATETIME NOT NULL CONSTRAINT DF_BitacoraAccesos_FecReg DEFAULT GETDATE()
);
GO

-- 2. Bitácora Unificada de Auditoría DML (REQ 005)
CREATE TABLE dbo.BitacoraAuditoria (
    fec_registro DATETIME NOT NULL CONSTRAINT DF_BitacoraAuditoria_FecReg DEFAULT GETDATE(),
    cod_guid UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_BitacoraAuditoria_Guid DEFAULT NEWID(),
    ind_accion CHAR(1) NOT NULL CONSTRAINT CK_BitacoraAuditoria_Accion CHECK (ind_accion IN ('I', 'D', 'U')),
    cod_usuario VARCHAR(100) NOT NULL,
    cod_sesion_usuario VARCHAR(100) NOT NULL,
    cod_tabla VARCHAR(100) NOT NULL,
    cod_llave VARCHAR(100) NOT NULL,
    des_datos NVARCHAR(MAX) NOT NULL -- Almacenamiento en estructura JSON o texto estructurado
);
GO

CREATE CLUSTERED INDEX IX_BitacoraAuditoria_FecReg ON dbo.BitacoraAuditoria(fec_registro);
GO