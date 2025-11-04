# 📚 BiblioGuest – Sistema de Gestión de Biblioteca  
**Universidad Nacional Mayor de San Marcos (UNMSM)**  
Facultad de Ingeniería de Sistemas e Informática  
📆 Curso: **Base de Datos II – Semestre 2025-2**

---

## 📦 Entrega Parcial 2

Esta entrega documenta y empaqueta el **Modelo Lógico (corregido)**, el **Modelo Físico (Oracle)** y el **Esquema Oracle** listo para despliegue con scripts de **creación**, **carga** y **programación almacenada**.

---

## 👥 Equipo – Grupo 07
**Docente:** Jorge Luis Chávez Soto  

- Solis Cunza, Miguel Alonso – 🧑‍💻 Coordinador  
- Matamoros Laura, Ricardo José – 👨‍💻 Desarrollador  
- Cristobal Rojas, Mihael Jhire – 👨‍💻 Desarrollador  
- Montes Ramos, Carol Sofía – 👩‍💻 Analista  
- Arroyo Tapia, Luis – 👨‍💻 Documentación  

---

## 🧭 Alcance de esta entrega

- ✅ **Modelo de Datos Lógico (versión corregida):** entidades/relaciones para **préstamo de libros** y **reservas** de **laptops** y **cubículos**, organizado por áreas (Recursos, Personas, Operaciones, Reglamentos).  
- ✅ **Modelo de Datos Físico (Oracle):** tipos, longitudes, **CHECKs**, **PK/UK/FK**, **índices**, y **convenciones de nombres**.  
- ✅ **Esquema Oracle** con scripts para:
  - **Esquema y objetos** (tablespaces, tablas, constraints, índices).  
  - **Datos semilla** coherentes.  
  - **Objetos de programación almacenados** (functions, procedures, triggers).

---

## 🛠️ Tecnologías y herramientas

- Oracle Database 
- Oracle SQL Developer 
- Oracle SQL Developer Data Modeler (modelo físico)  
- dbdiagram.io (histórico del lógico)  
- Git / GitHub (versionado)

---

## 🗂️ Archivos de la entrega

- **Modelo Logico de Datos.pdf**  
  Vista consolidada del modelo lógico de la base de datos

- **ModeloFisicoDeDatos.pdf**  
  Export del modelo físico en Oracle: tipos de datos, PK/UK/FK, CHECKs, índices y convenciones.

- **ScriptCreacion.sql**  
  Crea los **tablespaces** `BiblioGuest` (datos) y `BiblioGuestTemp` (temporal), el **esquema** (tablas, PK/UK/FK, índices)  

- **ScriptCreacionObjetosAlmacenados.sql**  
  Crea **functions**, **procedures** y **triggers** para reglas de negocio: normalización de horas, anti-solape de reservas, sincronización de estados, cálculo de multa, etc.

- **ScriptInsercionDatos.sql**  
  Carga de datos semilla consistente.

---

## 🔍 Verificación rápida

~~~sql
-- Conteo de Ingreso de datos hecho
SELECT 'Usuario' t, COUNT(*) n FROM Usuario UNION ALL
SELECT 'Libro', COUNT(*) FROM Libro UNION ALL
SELECT 'Ejemplar', COUNT(*) FROM Ejemplar UNION ALL
SELECT 'Laptop', COUNT(*) FROM Laptop UNION ALL
SELECT 'Cubiculo', COUNT(*) FROM Cubiculo UNION ALL
SELECT 'PrestamoLibro', COUNT(*) FROM PrestamoLibro UNION ALL
SELECT 'ReservaLaptop', COUNT(*) FROM ReservaLaptop UNION ALL
SELECT 'ReservaCubiculo', COUNT(*) FROM ReservaCubiculo;

-- Ver las constrains y los indices
SELECT constraint_name, table_name, status
FROM user_constraints
WHERE constraint_type IN ('P','R','U','C')
ORDER BY table_name;

SELECT index_name, table_name, status
FROM user_indexes
ORDER BY table_name;
~~~

---

## 🧠 Objetos de programación almacenados (incluidos)

- **Functions:**  
  `fn_minutos`, `fn_build_ts`, `fn_tiene_sancion_activa`,  
  `fn_reserva_solapa_laptop`, `fn_reserva_solapa_cubiculo`,  
  `fn_dias_atraso`, `fn_calcular_multa`.

- **Procedures:**  
  `pr_crear_prestamo_libro`, `pr_devolver_prestamo_libro`,  
  `pr_reservar_laptop`, `pr_cancelar_reserva_laptop`,  
  `pr_reservar_cubiculo`, `pr_cancelar_reserva_cubiculo`.

- **Triggers:**  
  Normalización de `HH24:MI` y anti-solape en reservas (`ReservaLaptop`, `ReservaCubiculo`),  
  ajuste de estado en `PrestamoLibro`,  
  sincronización `Ejemplar.estado` y `Usuario.estado` según sanciones.

