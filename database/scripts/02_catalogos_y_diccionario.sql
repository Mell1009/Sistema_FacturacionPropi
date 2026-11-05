/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Script   : 02_catalogos_y_diccionario.sql
   Propósito: 1) Carga los catálogos base (tipos de identificación e impuestos).
              2) Registra descripciones (extended properties) de tablas y
                 columnas para generar el diccionario de datos (REQ 010)
                 con tools/diccionario_datos.sql.
   Idempotente: puede ejecutarse varias veces.
   ===================================================================== */
USE PropiFacturacion;
GO
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1) Catálogos
   --------------------------------------------------------------------- */
INSERT INTO fact.TipoIdentificacion (cod_tipo_identificacion, des_tipo_identificacion)
SELECT v.cod, v.des
FROM (VALUES (1, 'Cédula física'),
             (2, 'Cédula jurídica'),
             (3, 'DIMEX'),
             (4, 'NITE')) AS v(cod, des)
WHERE NOT EXISTS (SELECT 1 FROM fact.TipoIdentificacion t WHERE t.cod_tipo_identificacion = v.cod);
GO

-- Tarifas de IVA de ejemplo (ajustar si el docente pide otras)
INSERT INTO fact.TipoImpuesto (cod_impuesto, des_impuesto, por_impuesto, mon_tarifa)
SELECT v.cod, v.des, v.por, 0
FROM (VALUES ('IVA13', 'IVA tarifa general 13%',   13.00),
             ('IVA4',  'IVA tarifa reducida 4%',    4.00),
             ('IVA2',  'IVA tarifa reducida 2%',    2.00),
             ('IVA1',  'IVA tarifa reducida 1%',    1.00),
             ('EXE',   'Exento / tarifa 0%',        0.00)) AS v(cod, des, por)
WHERE NOT EXISTS (SELECT 1 FROM fact.TipoImpuesto t WHERE t.cod_impuesto = v.cod);
GO

/* ---------------------------------------------------------------------
   2) Descripciones para el diccionario de datos (REQ 010)
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'tempdb..#desc') IS NOT NULL DROP TABLE #desc;
CREATE TABLE #desc
(
    esq   SYSNAME,
    tabla SYSNAME,
    col   SYSNAME       NULL,
    prop  SYSNAME,
    val   NVARCHAR(500)
);

INSERT INTO #desc (esq, tabla, col, prop, val) VALUES
-- ---- Tablas: nombre lógico y propósito
(N'fact', N'TipoIdentificacion', NULL, N'NombreLogico',   N'Tipos de identificación'),
(N'fact', N'TipoIdentificacion', NULL, N'MS_Description', N'Catálogo de documentos de identidad aceptados para los clientes.'),
(N'fact', N'Cliente',            NULL, N'NombreLogico',   N'Clientes'),
(N'fact', N'Cliente',            NULL, N'MS_Description', N'Registro de clientes a facturar. Identificación, correo y teléfono se almacenan cifrados (cell-level encryption).'),
(N'fact', N'TipoImpuesto',       NULL, N'NombreLogico',   N'Tipos de impuesto'),
(N'fact', N'TipoImpuesto',       NULL, N'MS_Description', N'Impuestos aplicables a los productos y servicios.'),
(N'fact', N'Producto',           NULL, N'NombreLogico',   N'Productos y servicios'),
(N'fact', N'Producto',           NULL, N'MS_Description', N'Catálogo de productos/servicios con código CABYS, precio e impuesto.'),
(N'fact', N'Factura',            NULL, N'NombreLogico',   N'Facturas'),
(N'fact', N'Factura',            NULL, N'MS_Description', N'Encabezado de la factura de venta de bienes raíces.'),
(N'fact', N'FacturaDetalle',     NULL, N'NombreLogico',   N'Detalle de factura'),
(N'fact', N'FacturaDetalle',     NULL, N'MS_Description', N'Líneas de producto/servicio de cada factura.'),
(N'fact', N'NotaCreditoDebito',  NULL, N'NombreLogico',   N'Notas de crédito y débito'),
(N'fact', N'NotaCreditoDebito',  NULL, N'MS_Description', N'Ajustes (crédito o débito) aplicados sobre facturas emitidas.'),
(N'seg',  N'BitacoraAcceso',     NULL, N'NombreLogico',   N'Bitácora de acceso'),
(N'seg',  N'BitacoraAcceso',     NULL, N'MS_Description', N'Control de ingresos y salidas de los usuarios a la aplicación (REQ 003).'),
(N'aud',  N'BitacoraAuditoria',  NULL, N'NombreLogico',   N'Bitácora de auditoría'),
(N'aud',  N'BitacoraAuditoria',  NULL, N'MS_Description', N'Pistas de auditoría: cada insert, update y delete queda registrado por triggers (REQ 005).'),

-- ---- fact.TipoIdentificacion
(N'fact', N'TipoIdentificacion', N'cod_tipo_identificacion', N'MS_Description', N'Identificador del tipo de identificación (1 Física, 2 Jurídica, 3 DIMEX, 4 NITE).'),
(N'fact', N'TipoIdentificacion', N'des_tipo_identificacion', N'MS_Description', N'Descripción del tipo de identificación.'),
(N'fact', N'TipoIdentificacion', N'ind_estado',              N'MS_Description', N'Estado del registro. Catálogo: A Activo, I Inactivo.'),

-- ---- fact.Cliente
(N'fact', N'Cliente', N'cod_cliente',             N'MS_Description', N'Identificador único del cliente (autoincremental).'),
(N'fact', N'Cliente', N'nom_cliente',             N'MS_Description', N'Nombre completo o razón social.'),
(N'fact', N'Cliente', N'cod_tipo_identificacion', N'MS_Description', N'Tipo de identificación del cliente.'),
(N'fact', N'Cliente', N'num_identificacion_cif',  N'MS_Description', N'Número de identificación CIFRADO (dato sensible, AES-256).'),
(N'fact', N'Cliente', N'hash_identificacion',     N'MS_Description', N'Hash SHA-256 de la identificación; garantiza unicidad y permite búsquedas sin descifrar.'),
(N'fact', N'Cliente', N'nom_provincia',           N'MS_Description', N'Provincia del domicilio.'),
(N'fact', N'Cliente', N'nom_canton',              N'MS_Description', N'Cantón del domicilio.'),
(N'fact', N'Cliente', N'nom_distrito',            N'MS_Description', N'Distrito del domicilio.'),
(N'fact', N'Cliente', N'nom_barrio',              N'MS_Description', N'Barrio del domicilio (opcional).'),
(N'fact', N'Cliente', N'des_profesion',           N'MS_Description', N'Profesión u oficio (opcional).'),
(N'fact', N'Cliente', N'des_actividad_economica', N'MS_Description', N'Actividad económica del cliente (opcional).'),
(N'fact', N'Cliente', N'des_correo_cif',          N'MS_Description', N'Correo electrónico CIFRADO (dato sensible).'),
(N'fact', N'Cliente', N'num_telefono_cif',        N'MS_Description', N'Teléfono CIFRADO (dato sensible, opcional).'),
(N'fact', N'Cliente', N'fec_registro',            N'MS_Description', N'Fecha y hora de registro del cliente.'),
(N'fact', N'Cliente', N'ind_estado',              N'MS_Description', N'Estado del cliente. Catálogo: A Activo, I Inactivo.'),

-- ---- fact.TipoImpuesto
(N'fact', N'TipoImpuesto', N'cod_tipo_impuesto', N'MS_Description', N'Identificador único del tipo de impuesto.'),
(N'fact', N'TipoImpuesto', N'cod_impuesto',      N'MS_Description', N'Código corto del impuesto (único).'),
(N'fact', N'TipoImpuesto', N'des_impuesto',      N'MS_Description', N'Descripción del impuesto.'),
(N'fact', N'TipoImpuesto', N'por_impuesto',      N'MS_Description', N'Porcentaje del impuesto (0 a 100).'),
(N'fact', N'TipoImpuesto', N'mon_tarifa',        N'MS_Description', N'Tarifa fija asociada (mayor o igual a 0).'),
(N'fact', N'TipoImpuesto', N'ind_estado',        N'MS_Description', N'Estado. Catálogo: A Activo, I Inactivo.'),

-- ---- fact.Producto
(N'fact', N'Producto', N'cod_producto',      N'MS_Description', N'Identificador único del producto/servicio.'),
(N'fact', N'Producto', N'cod_cabys',         N'MS_Description', N'Código CABYS de 13 dígitos (único).'),
(N'fact', N'Producto', N'des_producto',      N'MS_Description', N'Descripción del producto o servicio.'),
(N'fact', N'Producto', N'des_unidad_medida', N'MS_Description', N'Unidad de medida (por ejemplo Unid, Sp, m2).'),
(N'fact', N'Producto', N'mon_precio',        N'MS_Description', N'Precio unitario (mayor o igual a 0).'),
(N'fact', N'Producto', N'cod_tipo_impuesto', N'MS_Description', N'Impuesto que se aplica al producto.'),
(N'fact', N'Producto', N'ind_estado',        N'MS_Description', N'Estado. Catálogo: A Activo, I Inactivo.'),

-- ---- fact.Factura
(N'fact', N'Factura', N'num_factura',         N'MS_Description', N'Número consecutivo de la factura.'),
(N'fact', N'Factura', N'cod_cliente',         N'MS_Description', N'Cliente al que se factura.'),
(N'fact', N'Factura', N'fec_factura',         N'MS_Description', N'Fecha y hora de emisión.'),
(N'fact', N'Factura', N'ind_condicion_venta', N'MS_Description', N'Condición de venta. Catálogo: C Contado, R Crédito.'),
(N'fact', N'Factura', N'ind_medio_pago',      N'MS_Description', N'Medio de pago. Catálogo: E Efectivo, T Tarjeta, Q Cheque, F Transferencia, S SINPE Móvil, O Otros.'),
(N'fact', N'Factura', N'cod_moneda',          N'MS_Description', N'Moneda. Catálogo: CRC Colón, USD Dólar.'),
(N'fact', N'Factura', N'mon_tipo_cambio',     N'MS_Description', N'Tipo de cambio aplicado (mayor a 0).'),
(N'fact', N'Factura', N'des_observaciones',   N'MS_Description', N'Observaciones de la factura (opcional).'),
(N'fact', N'Factura', N'mon_subtotal',        N'MS_Description', N'Subtotal antes de impuestos.'),
(N'fact', N'Factura', N'mon_total_impuestos', N'MS_Description', N'Suma de impuestos de la factura.'),
(N'fact', N'Factura', N'mon_total',           N'MS_Description', N'Monto total = subtotal + impuestos (validado por CHECK).'),

-- ---- fact.FacturaDetalle
(N'fact', N'FacturaDetalle', N'num_factura',  N'MS_Description', N'Factura a la que pertenece la línea.'),
(N'fact', N'FacturaDetalle', N'num_linea',    N'MS_Description', N'Número de línea dentro de la factura.'),
(N'fact', N'FacturaDetalle', N'cod_producto', N'MS_Description', N'Producto o servicio facturado.'),
(N'fact', N'FacturaDetalle', N'num_cantidad', N'MS_Description', N'Cantidad facturada (mayor a 0).'),
(N'fact', N'FacturaDetalle', N'mon_linea',     N'MS_Description', N'Monto de la línea (cantidad por precio).'),

-- ---- fact.NotaCreditoDebito
(N'fact', N'NotaCreditoDebito', N'cod_nota',    N'MS_Description', N'Código único de la nota.'),
(N'fact', N'NotaCreditoDebito', N'fec_nota',    N'MS_Description', N'Fecha y hora de la nota.'),
(N'fact', N'NotaCreditoDebito', N'num_factura', N'MS_Description', N'Factura afectada.'),
(N'fact', N'NotaCreditoDebito', N'ind_tipo',    N'MS_Description', N'Tipo de nota. Catálogo: C Crédito, D Débito.'),
(N'fact', N'NotaCreditoDebito', N'des_motivo',  N'MS_Description', N'Motivo del ajuste.'),

-- ---- seg.BitacoraAcceso
(N'seg', N'BitacoraAcceso', N'cod_acceso',   N'MS_Description', N'Identificador del registro de acceso.'),
(N'seg', N'BitacoraAcceso', N'nom_usuario',  N'MS_Description', N'Usuario (login) que ingresó.'),
(N'seg', N'BitacoraAcceso', N'nom_terminal', N'MS_Description', N'Nombre del equipo desde el que ingresó.'),
(N'seg', N'BitacoraAcceso', N'dir_ip',       N'MS_Description', N'Dirección IP del cliente (IPv4 o IPv6).'),
(N'seg', N'BitacoraAcceso', N'fec_ingreso',  N'MS_Description', N'Fecha y hora de ingreso.'),
(N'seg', N'BitacoraAcceso', N'fec_salida',   N'MS_Description', N'Fecha y hora de salida (NULL si la sesión sigue abierta).'),
(N'seg', N'BitacoraAcceso', N'fec_registro', N'MS_Description', N'Fecha y hora en que se grabó el registro.'),

-- ---- aud.BitacoraAuditoria
(N'aud', N'BitacoraAuditoria', N'fec_registro',       N'MS_Description', N'Fecha y hora del registro en bitácora.'),
(N'aud', N'BitacoraAuditoria', N'cod_guid',           N'MS_Description', N'Identificador único del registro (NEWID()).'),
(N'aud', N'BitacoraAuditoria', N'ind_accion',         N'MS_Description', N'Acción. Catálogo: I Inserción, D Borrado, U Modificación.'),
(N'aud', N'BitacoraAuditoria', N'cod_usuario',        N'MS_Description', N'Usuario que ejecutó la acción.'),
(N'aud', N'BitacoraAuditoria', N'cod_sesion_usuario', N'MS_Description', N'Sesión de base de datos del usuario (SESSION_CONTEXT).'),
(N'aud', N'BitacoraAuditoria', N'cod_tabla',          N'MS_Description', N'Tabla afectada.'),
(N'aud', N'BitacoraAuditoria', N'cod_llave',          N'MS_Description', N'Llave primaria del registro afectado (trazabilidad).'),
(N'aud', N'BitacoraAuditoria', N'des_datos',          N'MS_Description', N'Datos de la acción en JSON; en update incluye ANTES y DESPUÉS.');

DECLARE @esq SYSNAME, @tabla SYSNAME, @col SYSNAME, @prop SYSNAME, @val NVARCHAR(500);
DECLARE @minor INT, @existe BIT, @l2type NVARCHAR(128);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT esq, tabla, col, prop, val FROM #desc;

OPEN cur;
FETCH NEXT FROM cur INTO @esq, @tabla, @col, @prop, @val;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @minor  = CASE WHEN @col IS NULL THEN 0
                       ELSE COLUMNPROPERTY(OBJECT_ID(@esq + N'.' + @tabla), @col, 'ColumnId') END;
    SET @l2type = CASE WHEN @col IS NULL THEN NULL ELSE N'COLUMN' END;

    SET @existe = CASE WHEN EXISTS (SELECT 1
                                    FROM sys.extended_properties
                                    WHERE class = 1
                                      AND major_id = OBJECT_ID(@esq + N'.' + @tabla)
                                      AND minor_id = @minor
                                      AND name = @prop)
                       THEN 1 ELSE 0 END;

    IF @existe = 1
        EXEC sys.sp_updateextendedproperty
             @name = @prop, @value = @val,
             @level0type = N'SCHEMA', @level0name = @esq,
             @level1type = N'TABLE',  @level1name = @tabla,
             @level2type = @l2type,   @level2name = @col;
    ELSE
        EXEC sys.sp_addextendedproperty
             @name = @prop, @value = @val,
             @level0type = N'SCHEMA', @level0name = @esq,
             @level1type = N'TABLE',  @level1name = @tabla,
             @level2type = @l2type,   @level2name = @col;

    FETCH NEXT FROM cur INTO @esq, @tabla, @col, @prop, @val;
END

CLOSE cur;
DEALLOCATE cur;
DROP TABLE #desc;
GO

PRINT '02_catalogos_y_diccionario.sql finalizado.';
GO
