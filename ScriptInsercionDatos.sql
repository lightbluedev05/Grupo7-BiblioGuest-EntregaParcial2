-- ============================================================
-- BiblioGuest - Script de Carga de Datos (CORREGIDO)
-- ============================================================

-- WHENEVER SQLERROR EXIT SQL.SQLCODE;  -- opcional para abortar ante error

-- 1) ÁREAS
VAR v_area_ing NUMBER
VAR v_area_hum NUMBER

INSERT INTO Areas (nombre_area) VALUES ('Ingeniería')
  RETURNING id_area INTO :v_area_ing;

INSERT INTO Areas (nombre_area) VALUES ('Humanidades')
  RETURNING id_area INTO :v_area_hum;

-- 2) NORMAS
VAR v_norma_std NUMBER
INSERT INTO NormasBiblioteca (dias_prestamo_libros, dias_anticipacion_libros, dias_anticipacion_cubiculos, dias_anticipacion_laptops)
VALUES (5, 2, 7, 1)
RETURNING id_normas_biblioteca INTO :v_norma_std;

-- 3) UNIDADES
VAR v_unmsm NUMBER
VAR v_fisi  NUMBER
VAR v_flch  NUMBER

INSERT INTO UnidadAcademica (nombre, tipo, id_area, id_padre)
VALUES ('Universidad Nacional Mayor de San Marcos', 'Universidad', NULL, NULL)
RETURNING id_unidad INTO :v_unmsm;

INSERT INTO UnidadAcademica (nombre, tipo, id_area, id_padre)
VALUES ('Facultad de Ingeniería de Sistemas e Informática', 'Facultad', :v_area_ing, :v_unmsm)
RETURNING id_unidad INTO :v_fisi;

INSERT INTO UnidadAcademica (nombre, tipo, id_area, id_padre)
VALUES ('Facultad de Letras y Ciencias Humanas', 'Facultad', :v_area_hum, :v_unmsm)
RETURNING id_unidad INTO :v_flch;

-- 4) BIBLIOTECAS
VAR v_biblio_central NUMBER
VAR v_biblio_fisi    NUMBER

INSERT INTO Biblioteca (id_normas_biblioteca, nombre, id_unidad)
VALUES (:v_norma_std, 'Biblioteca Central', :v_unmsm)
RETURNING id_biblioteca INTO :v_biblio_central;

INSERT INTO Biblioteca (id_normas_biblioteca, nombre, id_unidad)
VALUES (:v_norma_std, 'Biblioteca FISI', :v_fisi)
RETURNING id_biblioteca INTO :v_biblio_fisi;

-- 5) CONTACTOS + vínculos
VAR v_cto_central_email NUMBER
VAR v_cto_central_fono  NUMBER
VAR v_cto_fisi_email    NUMBER

INSERT INTO Contacto (tipo_contacto, valor_contacto) VALUES ('Email', 'central@unmsm.edu.pe')
  RETURNING id_contacto INTO :v_cto_central_email;
INSERT INTO Contacto (tipo_contacto, valor_contacto) VALUES ('Telefono', '+51 1 619-7000')
  RETURNING id_contacto INTO :v_cto_central_fono;
INSERT INTO Contacto (tipo_contacto, valor_contacto) VALUES ('Email', 'fisi@unmsm.edu.pe')
  RETURNING id_contacto INTO :v_cto_fisi_email;

INSERT INTO BibliotecaContacto (id_biblioteca, id_contacto) VALUES (:v_biblio_central, :v_cto_central_email);
INSERT INTO BibliotecaContacto (id_biblioteca, id_contacto) VALUES (:v_biblio_central, :v_cto_central_fono);
INSERT INTO UnidadContacto (id_unidad, id_contacto) VALUES (:v_fisi, :v_cto_fisi_email);

-- 6) GRUPO DE USUARIOS + USUARIOS
VAR v_grupo1 NUMBER
/* CORRECCIÓN: Oracle no soporta "DEFAULT VALUES".
   Insertamos el DEFAULT explícito de la columna identity. */
INSERT INTO GrupoUsuarios (id_grupo_usuarios) VALUES (DEFAULT)
RETURNING id_grupo_usuarios INTO :v_grupo1;

VAR v_user_mihael  NUMBER
VAR v_user_ricardo NUMBER
VAR v_user_maye    NUMBER

INSERT INTO Usuario (nombre, codigo_institucional, correo, estado, id_unidad)
VALUES ('Mihael Cristobal', '20201234', 'mihael@unmsm.edu.pe', 'activo', :v_fisi)
RETURNING id_usuario INTO :v_user_mihael;

INSERT INTO Usuario (nombre, codigo_institucional, correo, estado, id_unidad)
VALUES ('Ricardo Matamoros', '20205678', 'ricardo@unmsm.edu.pe', 'activo', :v_fisi)
RETURNING id_usuario INTO :v_user_ricardo;

INSERT INTO Usuario (nombre, codigo_institucional, correo, estado, id_unidad)
VALUES ('Maye Delgado', '20207890', 'maye@unmsm.edu.pe', 'activo', :v_flch)
RETURNING id_usuario INTO :v_user_maye;

-- Vincular usuarios al grupo (ya tenemos :v_grupo1)
INSERT INTO UsuarioGrupoUsuarios (id_usuario, id_grupo_usuarios) VALUES (:v_user_mihael,  :v_grupo1);
INSERT INTO UsuarioGrupoUsuarios (id_usuario, id_grupo_usuarios) VALUES (:v_user_ricardo, :v_grupo1);

-- 7) BIBLIOTECARIOS
VAR v_bib_ana  NUMBER
VAR v_bib_luis NUMBER

INSERT INTO Bibliotecario (nombre, correo, turno)
VALUES ('Ana Pérez', 'ana.perez@unmsm.edu.pe', 'Mañana')
RETURNING id_bibliotecario INTO :v_bib_ana;

INSERT INTO Bibliotecario (nombre, correo, turno)
VALUES ('Luis Rojas', 'luis.rojas@unmsm.edu.pe', 'Tarde')
RETURNING id_bibliotecario INTO :v_bib_luis;

-- 8) CATEGORÍAS y ETIQUETAS
VAR v_cat_cs NUMBER
VAR v_cat_bd NUMBER
VAR v_tag_unmsm NUMBER
VAR v_tag_invest NUMBER

INSERT INTO Categorias (nombre, descripcion) VALUES ('Ciencia de la Computación', 'Libros de CS/IT')
  RETURNING id_categoria INTO :v_cat_cs;
INSERT INTO Categorias (nombre, descripcion) VALUES ('Base de Datos', 'Teoría y práctica de BD')
  RETURNING id_categoria INTO :v_cat_bd;

INSERT INTO Etiquetas (nombre, descripcion) VALUES ('UNMSM', 'Colección UNMSM')
  RETURNING id_etiqueta INTO :v_tag_unmsm;
INSERT INTO Etiquetas (nombre, descripcion) VALUES ('Investigación', 'Material de investigación')
  RETURNING id_etiqueta INTO :v_tag_invest;

-- 9) LIBROS, AUTORES, RELACIONES, EJEMPLARES
VAR v_libro_db NUMBER
VAR v_libro_cc NUMBER

INSERT INTO Libro (isbn, titulo, subtitulo, editorial, nro_edicion, anio)
VALUES ('9780073523323', 'Database System Concepts', NULL, 'McGraw-Hill', 6, 2010)
RETURNING id_libro INTO :v_libro_db;

INSERT INTO Libro (isbn, titulo, subtitulo, editorial, nro_edicion, anio)
VALUES ('9780132350884', 'Clean Code', 'A Handbook of Agile Software Craftsmanship', 'Prentice Hall', 1, 2008)
RETURNING id_libro INTO :v_libro_cc;

VAR v_autor_silb  NUMBER
VAR v_autor_korth NUMBER
VAR v_autor_sudar NUMBER
VAR v_autor_uncle NUMBER

INSERT INTO Autor (nombre, apellido, nacionalidad) VALUES ('Abraham', 'Silberschatz', 'EE.UU.')
  RETURNING id_autor INTO :v_autor_silb;
INSERT INTO Autor (nombre, apellido, nacionalidad) VALUES ('Henry F.', 'Korth', 'EE.UU.')
  RETURNING id_autor INTO :v_autor_korth;
INSERT INTO Autor (nombre, apellido, nacionalidad) VALUES ('S.', 'Sudarshan', 'India')
  RETURNING id_autor INTO :v_autor_sudar;
INSERT INTO Autor (nombre, apellido, nacionalidad) VALUES ('Robert C.', 'Martin', 'EE.UU.')
  RETURNING id_autor INTO :v_autor_uncle;

-- LibroAutor
INSERT INTO LibroAutor (id_libro, id_autor) VALUES (:v_libro_db, :v_autor_silb);
INSERT INTO LibroAutor (id_libro, id_autor) VALUES (:v_libro_db, :v_autor_korth);
INSERT INTO LibroAutor (id_libro, id_autor) VALUES (:v_libro_db, :v_autor_sudar);
INSERT INTO LibroAutor (id_libro, id_autor) VALUES (:v_libro_cc, :v_autor_uncle);

-- CategoriasLibro
INSERT INTO CategoriasLibro (id_categoria, id_libro) VALUES (:v_cat_bd, :v_libro_db);
INSERT INTO CategoriasLibro (id_categoria, id_libro) VALUES (:v_cat_cs, :v_libro_cc);

-- Etiquetas por libro
INSERT INTO LibroEtiquetas (id_libro, id_etiqueta) VALUES (:v_libro_db, :v_tag_invest);
INSERT INTO LibroEtiquetas (id_libro, id_etiqueta) VALUES (:v_libro_cc, :v_tag_unmsm);

-- Ejemplares
VAR v_ej_db1 NUMBER
VAR v_ej_db2 NUMBER
VAR v_ej_cc1 NUMBER

INSERT INTO Ejemplar (id_libro, codigo_barra, estado, id_biblioteca)
VALUES (:v_libro_db, 'BC-DB-0001', 'disponible', :v_biblio_central)
RETURNING id_ejemplar INTO :v_ej_db1;

INSERT INTO Ejemplar (id_libro, codigo_barra, estado, id_biblioteca)
VALUES (:v_libro_db, 'BC-DB-0002', 'disponible', :v_biblio_central)
RETURNING id_ejemplar INTO :v_ej_db2;

INSERT INTO Ejemplar (id_libro, codigo_barra, estado, id_biblioteca)
VALUES (:v_libro_cc, 'FISI-CC-0001', 'disponible', :v_biblio_fisi)
RETURNING id_ejemplar INTO :v_ej_cc1;

-- 10) UTILIDADES y LAPTOPS
VAR v_util_clases NUMBER
VAR v_util_invest NUMBER

INSERT INTO Utilidad (nombre_utilidad) VALUES ('Clases')
  RETURNING id_utilidad INTO :v_util_clases;
INSERT INTO Utilidad (nombre_utilidad) VALUES ('Investigación')
  RETURNING id_utilidad INTO :v_util_invest;

VAR v_lap_sn1 NUMBER
VAR v_lap_sn2 NUMBER

INSERT INTO Laptop (id_biblioteca, numero_serie, sistema_operativo, marca, modelo, id_utilidad, estado)
VALUES (:v_biblio_central, 'SN-001', 'Windows 11', 'Dell', 'Latitude 5420', :v_util_clases, 'disponible')
RETURNING id_laptop INTO :v_lap_sn1;

INSERT INTO Laptop (id_biblioteca, numero_serie, sistema_operativo, marca, modelo, id_utilidad, estado)
VALUES (:v_biblio_fisi, 'SN-002', 'Ubuntu 22.04', 'Lenovo', 'ThinkPad X1', :v_util_invest, 'disponible')
RETURNING id_laptop INTO :v_lap_sn2;

-- 11) CUBÍCULOS
VAR v_cub1 NUMBER
VAR v_cub2 NUMBER

INSERT INTO Cubiculo (capacidad, id_biblioteca, estado)
VALUES (4, :v_biblio_central, 'disponible')
RETURNING id_cubiculo INTO :v_cub1;

INSERT INTO Cubiculo (capacidad, id_biblioteca, estado)
VALUES (6, :v_biblio_central, 'disponible')
RETURNING id_cubiculo INTO :v_cub2;

-- 12) PRÉSTAMO de un ejemplar
VAR v_prestamo1 NUMBER

UPDATE Ejemplar SET estado = 'prestado' WHERE id_ejemplar = :v_ej_cc1;

INSERT INTO PrestamoLibro (id_usuario, id_bibliotecario, id_ejemplar, fecha_solicitud, fecha_inicio, fecha_fin, fecha_devolucion_real, estado)
VALUES (:v_user_mihael, :v_bib_ana, :v_ej_cc1,
        SYSTIMESTAMP, DATE '2025-11-03', DATE '2025-11-08', NULL, 'activo')
RETURNING id_prestamo INTO :v_prestamo1;

-- 13) RESERVAS (con horas normalizadas para pasar el CHECK)
VAR v_res_lap1 NUMBER
VAR v_res_cub1 NUMBER

INSERT INTO ReservaLaptop (id_usuario, id_bibliotecario, id_laptop, fecha_solicitud, fecha_reserva, hora_inicio, hora_fin, estado)
VALUES (:v_user_ricardo, :v_bib_ana, :v_lap_sn1,
        SYSTIMESTAMP, DATE '2025-11-05',
        '09:00',
        '11:00',
        'activa')
RETURNING id_reserva INTO :v_res_lap1;

INSERT INTO ReservaCubiculo (id_grupo_usuarios, id_bibliotecario, id_cubiculo, fecha_solicitud, fecha_reserva, hora_inicio, hora_fin, estado)
VALUES (:v_grupo1, :v_bib_luis, :v_cub1,
        SYSTIMESTAMP, DATE '2025-11-06',
        '10:00',
        '12:00',
        'activa')
RETURNING id_reserva INTO :v_res_cub1;

-- 14) SANCIONES (ejemplo)
VAR v_sancion1 NUMBER
INSERT INTO Sancion (id_usuario, motivo, fecha_inicio, fecha_fin, estado)
VALUES (:v_user_maye, 'Retraso en devolución (caso de prueba)', DATE '2025-10-01', DATE '2025-10-03', 'cumplida')
RETURNING id_sancion INTO :v_sancion1;

COMMIT;
