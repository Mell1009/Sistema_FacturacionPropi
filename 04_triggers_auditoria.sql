/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Script   : 04_triggers_auditoria.sql
   Propósito: Pistas de auditoría (REQ 005). Genera 3 triggers (I, U, D)
              por cada tabla de negocio y de acceso, a partir de UNA plantilla.
   Idempotente: usa CREATE OR ALTER.

   Tablas auditadas : todas las de los esquemas fact y seg (8 tablas = 24 triggers).
   Tabla de bitácora: aud.BitacoraAuditoria no se audita a sí misma (recursión);
                      en su lugar se protege como "solo inserción" con un
                      trigger INSTEAD OF UPDATE/DELETE (al final del script).

   Qué registra cada fila de bitácora
     ind_accion         I / U / D
     cod_usuario        ORIGINAL_LOGIN()  (el login real, aunque haya EXECUTE AS)
     cod_sesion_usuario SESSION_CONTEXT('cod_sesion'), que fija app.usp_Acceso_Registrar
     cod_tabla          esquema.tabla
     cod_llave          PK, p. ej.  cod_cliente=15   o   num_factura=3|num_linea=2
     des_datos          JSON. Insert/Delete: el registro. Update: {"ANTES":{..},"DESPUES":{..}}

   Seguridad: las columnas cifradas (*_cif) y hash_identificacion NO se
   vuelcan a la bitácora, para no filtrar datos sensibles (REQ 006).
   ===================================================================== */
USE PropiFacturacion;
GO
SET NOCOUNT ON;
GO

DECLARE @esq SYSNAME, @tab SYSNAME, @obj INT;
DECLARE @keyExpr NVARCHAR(MAX), @colsExpr NVARCHAR(MAX), @joinExpr NVARCHAR(MAX);
DECLARE @full NVARCHAR(300), @tblName NVARCHAR(300), @sql NVARCHAR(MAX);
DECLARE @tI NVARCHAR(MAX), @tU NVARCHAR(MAX), @tD NVARCHAR(MAX);

/* ---- Plantillas (tokens ~X~ se reemplazan por tabla) ---- */
SET @tI = N'CREATE OR ALTER TRIGGER ~TRG~ ON ~TBL~ AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO aud.BitacoraAuditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT ''I'', ORIGINAL_LOGIN(), CONVERT(VARCHAR(64), SESSION_CONTEXT(N''cod_sesion'')), ''~TBLNAME~'',
           ~KEY_I~,
           (SELECT ~COLS_I~ FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted AS i;
END';

SET @tD = N'CREATE OR ALTER TRIGGER ~TRG~ ON ~TBL~ AFTER DELETE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO aud.BitacoraAuditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT ''D'', ORIGINAL_LOGIN(), CONVERT(VARCHAR(64), SESSION_CONTEXT(N''cod_sesion'')), ''~TBLNAME~'',
           ~KEY_D~,
           (SELECT ~COLS_D~ FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted AS d;
END';

SET @tU = N'CREATE OR ALTER TRIGGER ~TRG~ ON ~TBL~ AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO aud.BitacoraAuditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT ''U'', ORIGINAL_LOGIN(), CONVERT(VARCHAR(64), SESSION_CONTEXT(N''cod_sesion'')), ''~TBLNAME~'',
           ~KEY_I~,
           (SELECT JSON_QUERY((SELECT ~COLS_D~ FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)) AS ANTES,
                   JSON_QUERY((SELECT ~COLS_I~ FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)) AS DESPUES
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted AS i
    JOIN deleted  AS d ON ~JOIN~;
END';

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.name, t.name, t.object_id
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name IN (N'fact', N'seg')
    ORDER BY s.name, t.name;

OPEN cur;
FETCH NEXT FROM cur INTO @esq, @tab, @obj;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @full    = QUOTENAME(@esq) + N'.' + QUOTENAME(@tab);
    SET @tblName = @esq + N'.' + @tab;

    -- Expresión de la llave primaria: N'col=' + CONVERT(...) + N'|' + ...
    SELECT @keyExpr = STRING_AGG(
               CONVERT(NVARCHAR(MAX), N'N''' + c.name + N'='' + CONVERT(NVARCHAR(100), ~A~.' + QUOTENAME(c.name) + N')'),
               N' + N''|'' + ') WITHIN GROUP (ORDER BY ic.key_ordinal)
    FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c        ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = @obj AND i.is_primary_key = 1;

    -- Condición de join por PK (para el trigger de update)
    SELECT @joinExpr = STRING_AGG(
               CONVERT(NVARCHAR(MAX), N'i.' + QUOTENAME(c.name) + N' = d.' + QUOTENAME(c.name)), N' AND ')
    FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c        ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = @obj AND i.is_primary_key = 1;

    -- Columnas a auditar (se excluyen las cifradas y el hash de identificación)
    SELECT @colsExpr = STRING_AGG(CONVERT(NVARCHAR(MAX), N'~A~.' + QUOTENAME(c.name)), N', ')
                       WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    WHERE c.object_id = @obj
      AND c.name NOT LIKE N'%[_]cif'
      AND c.name <> N'hash_identificacion';

    -- INSERT
    SET @sql = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@tI,
               N'~TRG~',     QUOTENAME(@esq) + N'.' + QUOTENAME(N'trg_' + @tab + N'_aud_I')),
               N'~TBL~',     @full),
               N'~TBLNAME~', @tblName),
               N'~KEY_I~',   REPLACE(@keyExpr,  N'~A~', N'i')),
               N'~COLS_I~',  REPLACE(@colsExpr, N'~A~', N'i'));
    EXEC sys.sp_executesql @sql;

    -- DELETE
    SET @sql = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@tD,
               N'~TRG~',     QUOTENAME(@esq) + N'.' + QUOTENAME(N'trg_' + @tab + N'_aud_D')),
               N'~TBL~',     @full),
               N'~TBLNAME~', @tblName),
               N'~KEY_D~',   REPLACE(@keyExpr,  N'~A~', N'd')),
               N'~COLS_D~',  REPLACE(@colsExpr, N'~A~', N'd'));
    EXEC sys.sp_executesql @sql;

    -- UPDATE
    SET @sql = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@tU,
               N'~TRG~',     QUOTENAME(@esq) + N'.' + QUOTENAME(N'trg_' + @tab + N'_aud_U')),
               N'~TBL~',     @full),
               N'~TBLNAME~', @tblName),
               N'~KEY_I~',   REPLACE(@keyExpr,  N'~A~', N'i')),
               N'~COLS_I~',  REPLACE(@colsExpr, N'~A~', N'i')),
               N'~COLS_D~',  REPLACE(@colsExpr, N'~A~', N'd')),
               N'~JOIN~',    @joinExpr);
    EXEC sys.sp_executesql @sql;

    PRINT N'Triggers de auditoría (I/U/D) listos para ' + @tblName;
    FETCH NEXT FROM cur INTO @esq, @tab, @obj;
END
CLOSE cur;
DEALLOCATE cur;
GO

/* ---------------------------------------------------------------------
   La bitácora de auditoría es de SOLO INSERCIÓN (nadie, ni el admin,
   puede alterar o borrar pistas). Los triggers de arriba la alimentan.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER aud.trg_BitacoraAuditoria_inmutable
ON aud.BitacoraAuditoria
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51000, N'La bitácora de auditoría es de solo inserción: no se permite modificar ni borrar.', 1;
END
GO

PRINT '04_triggers_auditoria.sql finalizado.';
GO
