/* =====================================================================
   Proyecto : Sistema de Gestión de Facturación Propi
   Script   : 09_datos_prueba.sql
   Propósito: Carga datos sintéticos para validar la optimización (REQ 009).
              Cada bloque se salta si su tabla ya tiene datos (idempotente).

   Volumen  : Cliente 1,000 · Producto 1,000 · Factura 1,000 (~2,500 líneas)
              NotaCreditoDebito 1,000 · BitacoraAcceso 1,000
              + la bitácora de auditoría se llena sola vía triggers.
   Catálogos: TipoIdentificacion (4) y TipoImpuesto (5) son catálogos
              pequeños por naturaleza; no tiene sentido inflarlos a 1,000.

   Los clientes se cifran con la clave de ESTA máquina (REQ 006); por eso
   los datos de prueba se generan aquí y no se mueven entre equipos.
   IMPORTANTE para REQ 009: ejecutar este script ANTES de 08_indices.sql,
   medir los planes "antes", y luego crear los índices y medir "después".
   ===================================================================== */
USE PropiFacturacion;
GO
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   Clientes (cifrados)
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM fact.Cliente)
BEGIN
    OPEN SYMMETRIC KEY sk_Propi_Datos DECRYPTION BY CERTIFICATE cert_Propi_Datos;

    ;WITH n AS
    (
        SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ),
    d AS
    (
        SELECT n,
               CONVERT(TINYINT, CASE WHEN n % 5 = 0 THEN 2 ELSE 1 END) AS tipo,
               CONCAT(1 + n % 9, '-', RIGHT('0000' + CONVERT(VARCHAR(10), 1000 + n), 4), '-',
                      RIGHT('0000' + CONVERT(VARCHAR(10), (n * 7) % 10000), 4)) AS ident
        FROM n
    )
    INSERT INTO fact.Cliente
        (nom_cliente, cod_tipo_identificacion, num_identificacion_cif, hash_identificacion,
         nom_provincia, nom_canton, nom_distrito, nom_barrio, des_profesion, des_actividad_economica,
         des_correo_cif, num_telefono_cif, fec_registro, ind_estado)
    SELECT
        CASE WHEN d.tipo = 2
             THEN CONCAT(CHOOSE(d.n % 6 + 1, 'Inversiones', 'Constructora', 'Desarrollos', 'Servicios', 'Grupo', 'Inmobiliaria'),
                         ' ', CHOOSE(d.n % 7 + 1, 'Cartago', 'Orosi', 'Tierra Blanca', 'Del Valle', 'Paraíso', 'Los Ángeles', 'Pacayas'),
                         ' S.A. #', d.n)
             ELSE CONCAT(CHOOSE(d.n % 10 + 1, 'María', 'José', 'Ana', 'Carlos', 'Laura', 'Luis', 'Sofía', 'Diego', 'Valeria', 'Andrés'), ' ',
                         CHOOSE((d.n / 10) % 10 + 1, 'Mora', 'Solano', 'Vargas', 'Rojas', 'Jiménez', 'Araya', 'Calvo', 'Chaves', 'Quesada', 'Brenes'), ' ',
                         CHOOSE((d.n / 3) % 8 + 1, 'Cordero', 'Fallas', 'Núñez', 'Salas', 'Ulate', 'Mata', 'Villalobos', 'Zúñiga'))
        END,
        d.tipo,
        ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(150), d.ident)),
        HASHBYTES('SHA2_256', CONCAT(d.tipo, '|', UPPER(REPLACE(d.ident, '-', '')))),
        CHOOSE(d.n % 7 + 1, 'Cartago', 'Cartago', 'Cartago', 'San José', 'Heredia', 'Alajuela', 'Limón'),
        CHOOSE(d.n % 7 + 1, 'Paraíso', 'Cartago', 'Jiménez', 'Escazú', 'Heredia', 'Alajuela', 'Limón'),
        CHOOSE(d.n % 7 + 1, 'Orosi', 'Oriental', 'Juan Viñas', 'San Rafael', 'Mercedes', 'San José', 'Valle La Estrella'),
        CASE WHEN d.n % 4 = 0 THEN NULL ELSE CONCAT('Barrio ', CHOOSE(d.n % 5 + 1, 'Centro', 'Los Pinos', 'La Esperanza', 'San Martín', 'El Carmen')) END,
        CHOOSE(d.n % 6 + 1, 'Ingeniero', 'Docente', 'Comerciante', 'Médico', 'Contador', 'Abogado'),
        CHOOSE(d.n % 6 + 1, 'Servicios profesionales', 'Educación', 'Comercio al por menor', 'Salud humana', 'Contabilidad', 'Actividades jurídicas'),
        ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(250), CONCAT('cliente', d.n, '@propi-demo.cr'))),
        ENCRYPTBYKEY(KEY_GUID(N'sk_Propi_Datos'), CONVERT(VARCHAR(150), CONCAT('8', RIGHT('0000000' + CONVERT(VARCHAR(10), 1000000 + d.n * 37), 7)))),
        DATEADD(MINUTE, -(d.n * 13) % 1440, DATEADD(DAY, -(d.n % 365), GETDATE())),
        CASE WHEN d.n % 10 = 0 THEN 'I' ELSE 'A' END
    FROM d;

    CLOSE SYMMETRIC KEY sk_Propi_Datos;
    PRINT 'Clientes de prueba cargados.';
END
ELSE PRINT 'Clientes: ya había datos, se omite.';
GO

/* ---------------------------------------------------------------------
   Productos / servicios
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM fact.Producto)
BEGIN
    DECLARE @nImp INT = (SELECT COUNT(*) FROM fact.TipoImpuesto);

    ;WITH n AS
    (
        SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    )
    INSERT INTO fact.Producto (cod_cabys, des_producto, des_unidad_medida, mon_precio, cod_tipo_impuesto, ind_estado)
    SELECT
        RIGHT('0000000000000' + CONVERT(VARCHAR(20), 4000000000000 + n.n * 13), 13),
        CONCAT(CHOOSE(n.n % 8 + 1, 'Lote residencial', 'Apartamento', 'Casa de habitación', 'Local comercial',
                                   'Comisión por venta', 'Asesoría inmobiliaria', 'Avalúo', 'Alquiler mensual'), ' #', n.n),
        CHOOSE(n.n % 3 + 1, 'Unid', 'Sp', 'm2'),
        CONVERT(DECIMAL(18,2), 25000 + (n.n * 977) % 4975000 + (n.n % 100) / 100.0),
        (SELECT ti.cod_tipo_impuesto
         FROM fact.TipoImpuesto ti
         ORDER BY ti.cod_tipo_impuesto
         OFFSET (n.n % @nImp) ROWS FETCH NEXT 1 ROWS ONLY),
        CASE WHEN n.n % 25 = 0 THEN 'I' ELSE 'A' END
    FROM n;

    PRINT 'Productos de prueba cargados.';
END
ELSE PRINT 'Productos: ya había datos, se omite.';
GO

/* ---------------------------------------------------------------------
   Facturas: encabezado -> detalle -> recalculo de totales
   (misma fórmula que app.usp_Factura_Insertar)
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM fact.Factura)
BEGIN
    DECLARE @nCli INT = (SELECT COUNT(*) FROM fact.Cliente WHERE ind_estado = 'A');

    ;WITH n AS
    (
        SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    )
    INSERT INTO fact.Factura (cod_cliente, fec_factura, ind_condicion_venta, ind_medio_pago, cod_moneda, mon_tipo_cambio, des_observaciones)
    SELECT
        (SELECT c.cod_cliente FROM fact.Cliente c WHERE c.ind_estado = 'A'
         ORDER BY c.cod_cliente OFFSET ((n.n * 7) % @nCli) ROWS FETCH NEXT 1 ROWS ONLY),
        DATEADD(MINUTE, -(n.n * 17) % 1440, DATEADD(DAY, -(n.n % 120), GETDATE())),
        CASE WHEN n.n % 3 = 0 THEN 'R' ELSE 'C' END,
        CHOOSE(n.n % 6 + 1, 'E', 'T', 'Q', 'F', 'S', 'O'),
        CASE WHEN n.n % 10 = 0 THEN 'USD' ELSE 'CRC' END,
        CASE WHEN n.n % 10 = 0 THEN 515.5000 ELSE 1.0000 END,
        CONCAT('Carga demo #', n.n)
    FROM n;

    -- Detalle: de 1 a 4 líneas por factura
    DECLARE @nProd INT = (SELECT COUNT(*) FROM fact.Producto WHERE ind_estado = 'A');

    ;WITH f AS
    (
        SELECT num_factura, ROW_NUMBER() OVER (ORDER BY num_factura) AS rn
        FROM fact.Factura
        WHERE des_observaciones LIKE 'Carga demo #%'
    ),
    l AS
    (
        SELECT f.num_factura, f.rn, v.num_linea
        FROM f
        CROSS APPLY (VALUES (1), (2), (3), (4)) v(num_linea)
        WHERE v.num_linea <= 1 + (f.rn % 4)
    ),
    x AS
    (
        SELECT l.num_factura, l.num_linea,
               (SELECT p.cod_producto FROM fact.Producto p WHERE p.ind_estado = 'A'
                ORDER BY p.cod_producto OFFSET ((l.rn * l.num_linea * 11) % @nProd) ROWS FETCH NEXT 1 ROWS ONLY) AS cod_producto,
               CONVERT(DECIMAL(12,2), 1 + ((l.rn + l.num_linea) % 5)) AS num_cantidad
        FROM l
    )
    INSERT INTO fact.FacturaDetalle (num_factura, num_linea, cod_producto, num_cantidad, mon_linea)
    SELECT x.num_factura, x.num_linea, x.cod_producto, x.num_cantidad,
           CONVERT(DECIMAL(18,2), ROUND(x.num_cantidad * p.mon_precio, 2))
    FROM x
    JOIN fact.Producto p ON p.cod_producto = x.cod_producto;

    -- Totales
    UPDATE f
       SET mon_subtotal        = t.sub,
           mon_total_impuestos = t.imp,
           mon_total           = t.sub + t.imp
    FROM fact.Factura f
    CROSS APPLY (SELECT SUM(d.mon_linea) AS sub,
                        SUM(CONVERT(DECIMAL(18,2), ROUND(d.mon_linea * ti.por_impuesto / 100.0, 2))) AS imp
                 FROM fact.FacturaDetalle d
                 JOIN fact.Producto p      ON p.cod_producto = d.cod_producto
                 JOIN fact.TipoImpuesto ti ON ti.cod_tipo_impuesto = p.cod_tipo_impuesto
                 WHERE d.num_factura = f.num_factura) t
    WHERE f.des_observaciones LIKE 'Carga demo #%';

    PRINT 'Facturas y detalle de prueba cargados.';
END
ELSE PRINT 'Facturas: ya había datos, se omite.';
GO

/* ---------------------------------------------------------------------
   Notas de crédito / débito
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM fact.NotaCreditoDebito)
BEGIN
    DECLARE @nFac INT = (SELECT COUNT(*) FROM fact.Factura);

    ;WITH n AS
    (
        SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    )
    INSERT INTO fact.NotaCreditoDebito (fec_nota, num_factura, ind_tipo, des_motivo)
    SELECT
        DATEADD(MINUTE, -(n.n * 19) % 1440, DATEADD(DAY, -(n.n % 90), GETDATE())),
        (SELECT f.num_factura FROM fact.Factura f
         ORDER BY f.num_factura OFFSET ((n.n * 3) % @nFac) ROWS FETCH NEXT 1 ROWS ONLY),
        CASE WHEN n.n % 3 = 0 THEN 'D' ELSE 'C' END,
        CHOOSE(n.n % 5 + 1, 'Devolución parcial', 'Error en el precio', 'Descuento posterior a la venta',
                            'Cargo por intereses de mora', 'Corrección de cantidad')
    FROM n;

    PRINT 'Notas de prueba cargadas.';
END
ELSE PRINT 'Notas: ya había datos, se omite.';
GO

/* ---------------------------------------------------------------------
   Bitácora de acceso (datos históricos simulados)
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM seg.BitacoraAcceso)
BEGIN
    ;WITH n AS
    (
        SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ),
    d AS
    (
        SELECT n.n, DATEADD(MINUTE, -(n.n * 29) % 1440, DATEADD(DAY, -(n.n % 60), GETDATE())) AS ingreso
        FROM n
    )
    INSERT INTO seg.BitacoraAcceso (nom_usuario, nom_terminal, dir_ip, fec_ingreso, fec_salida, fec_registro)
    SELECT CHOOSE(d.n % 3 + 1, 'propi_admin', 'propi_digitador', 'propi_consulta'),
           CONCAT('PC-', RIGHT('000' + CONVERT(VARCHAR(5), d.n % 40), 3)),
           CONCAT('192.168.1.', 10 + d.n % 200),
           d.ingreso,
           DATEADD(MINUTE, 5 + d.n % 120, d.ingreso),
           d.ingreso
    FROM d;

    PRINT 'Bitácora de acceso de prueba cargada.';
END
ELSE PRINT 'BitacoraAcceso: ya había datos, se omite.';
GO

/* ---------------------------------------------------------------------
   Resumen de volúmenes
   --------------------------------------------------------------------- */
SELECT s.name + N'.' + t.name AS tabla, SUM(p.rows) AS filas
FROM sys.tables t
JOIN sys.schemas s    ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY s.name, t.name;
GO

PRINT '09_datos_prueba.sql finalizado.';
GO
