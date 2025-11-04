--------------------- FUNCIONES ---------------------------
------- Convierte 'HH24:MI' a minutos desde 00:00 (para comparar horas)
CREATE OR REPLACE FUNCTION fn_minutos(p_hhmi VARCHAR2) RETURN NUMBER IS
  v_h NUMBER; v_m NUMBER; v_pos NUMBER;
BEGIN
  v_pos := INSTR(p_hhmi, ':');
  IF v_pos = 0 THEN RETURN NULL; END IF;
  v_h := TO_NUMBER(SUBSTR(p_hhmi, 1, v_pos-1));
  v_m := TO_NUMBER(SUBSTR(p_hhmi, v_pos+1, 2));
  RETURN v_h*60 + v_m;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
/

------- Construye TIMESTAMP a partir de una fecha y un 'HH24:MI'
CREATE OR REPLACE FUNCTION fn_build_ts(p_fecha DATE, p_hhmi VARCHAR2) RETURN TIMESTAMP IS
BEGIN
  RETURN TO_TIMESTAMP(TO_CHAR(p_fecha,'YYYY-MM-DD')||' '||p_hhmi,'YYYY-MM-DD HH24:MI');
END;
/

---------- ¿Usuario posee sanción activa hoy? (1/0)
CREATE OR REPLACE FUNCTION fn_tiene_sancion_activa(p_usuario NUMBER) RETURN NUMBER IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_cnt
    FROM Sancion
   WHERE id_usuario = p_usuario
     AND estado = 'activa'
     AND TRUNC(SYSDATE) BETWEEN NVL(fecha_inicio, TRUNC(SYSDATE))
                             AND NVL(fecha_fin,    DATE '9999-12-31');
  ROLLBACK; -- cerrar la transacción autónoma (solo lectura)
  RETURN CASE WHEN v_cnt > 0 THEN 1 ELSE 0 END;
END;
/

-- ¿Existe solape con reservas de LAPTOP activas para el mismo recurso/fecha?
CREATE OR REPLACE FUNCTION fn_reserva_solapa_laptop(
  p_id_laptop   NUMBER,
  p_fecha       DATE,
  p_ini         VARCHAR2,
  p_fin         VARCHAR2,
  p_ignorar_id  NUMBER DEFAULT NULL
) RETURN NUMBER IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_cnt
    FROM ReservaLaptop r
   WHERE r.id_laptop = p_id_laptop
     AND r.fecha_reserva = p_fecha
     AND r.estado = 'activa'
     AND fn_build_ts(r.fecha_reserva, r.hora_inicio) < fn_build_ts(p_fecha, p_fin)
     AND fn_build_ts(r.fecha_reserva, r.hora_fin)    > fn_build_ts(p_fecha, p_ini)
     AND NVL(r.id_reserva, -1) <> NVL(p_ignorar_id, -1);

  ROLLBACK;
  RETURN CASE WHEN v_cnt > 0 THEN 1 ELSE 0 END;
END;
/

-------- ¿Existe solape con reservas de CUBÍCULO activas?
CREATE OR REPLACE FUNCTION fn_reserva_solapa_cubiculo(
  p_id_cubiculo NUMBER,
  p_fecha       DATE,
  p_ini         VARCHAR2,
  p_fin         VARCHAR2,
  p_ignorar_id  NUMBER DEFAULT NULL
) RETURN NUMBER IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_cnt
    FROM ReservaCubiculo r
   WHERE r.id_cubiculo = p_id_cubiculo
     AND r.fecha_reserva = p_fecha
     AND r.estado = 'activa'
     AND fn_build_ts(r.fecha_reserva, r.hora_inicio) < fn_build_ts(p_fecha, p_fin)
     AND fn_build_ts(r.fecha_reserva, r.hora_fin)    > fn_build_ts(p_fecha, p_ini)
     AND NVL(r.id_reserva, -1) <> NVL(p_ignorar_id, -1);

  ROLLBACK;
  RETURN CASE WHEN v_cnt > 0 THEN 1 ELSE 0 END;
END;
/

--------- Días de atraso (>=0) y multa simple (monto x día) sobre PrestamoLibro
CREATE OR REPLACE FUNCTION fn_dias_atraso(p_prestamo NUMBER) RETURN NUMBER IS
  v_fin DATE; v_dev DATE;
BEGIN
  SELECT fecha_fin, NVL(fecha_devolucion_real, TRUNC(SYSDATE))
    INTO v_fin, v_dev
    FROM PrestamoLibro
   WHERE id_prestamo = p_prestamo;

  RETURN GREATEST(0, TRUNC(v_dev) - TRUNC(v_fin));
END;
/

CREATE OR REPLACE FUNCTION fn_calcular_multa(
  p_prestamo     NUMBER,
  p_monto_diario NUMBER DEFAULT 1
) RETURN NUMBER IS
BEGIN
  RETURN fn_dias_atraso(p_prestamo) * NVL(p_monto_diario,1);
END;
/


----------------- PROCDURES ----------------------
------ Crear préstamo de libro (usa Normas de la Biblioteca del Ejemplar)
CREATE OR REPLACE PROCEDURE pr_crear_prestamo_libro(
  p_usuario        IN  NUMBER,
  p_ejemplar       IN  NUMBER,
  p_bibliotecario  IN  NUMBER,
  p_id_prestamo    OUT NUMBER
) IS
  v_estado_usr   VARCHAR2(15);
  v_activa       NUMBER;
  v_estado_ej    VARCHAR2(15);
  v_biblio       NUMBER;
  v_dias         NUMBER;
  v_fin          DATE;
BEGIN
  --- Validar usuario
  SELECT estado INTO v_estado_usr FROM Usuario WHERE id_usuario = p_usuario;
  IF v_estado_usr = 'bloqueado' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Usuario bloqueado');
  END IF;

  v_activa := fn_tiene_sancion_activa(p_usuario);
  IF v_activa = 1 THEN
    RAISE_APPLICATION_ERROR(-20002, 'Usuario con sanción activa');
  END IF;

  ---- Validar ejemplar y estado
  SELECT e.estado, e.id_biblioteca INTO v_estado_ej, v_biblio
    FROM Ejemplar e WHERE e.id_ejemplar = p_ejemplar
    FOR UPDATE; -- bloquear ejemplar para evitar carreras

  IF v_estado_ej <> 'disponible' THEN
    RAISE_APPLICATION_ERROR(-20003, 'Ejemplar no disponible');
  END IF;

  ---- Días de préstamo desde Normas de la biblioteca (fallback 5 días)
  SELECT NVL(nb.dias_prestamo_libros, 5)
    INTO v_dias
    FROM Biblioteca b
    LEFT JOIN NormasBiblioteca nb ON nb.id_normas_biblioteca = b.id_normas_biblioteca
   WHERE b.id_biblioteca = v_biblio;

  v_fin := TRUNC(SYSDATE) + v_dias;

  INSERT INTO PrestamoLibro(
    id_usuario, id_bibliotecario, id_ejemplar,
    fecha_solicitud, fecha_inicio, fecha_fin, fecha_devolucion_real, estado
  ) VALUES (
    p_usuario, p_bibliotecario, p_ejemplar,
    SYSTIMESTAMP, TRUNC(SYSDATE), v_fin, NULL, 'activo'
  )
  RETURNING id_prestamo INTO p_id_prestamo;

  --- El trigger sincroniza el estado del Ejemplar a 'prestado'
END;
/

--------------------- Devolver préstamo (marca devolución real = hoy por defecto)
CREATE OR REPLACE PROCEDURE pr_devolver_prestamo_libro(
  p_prestamo IN NUMBER,
  p_fecha    IN DATE DEFAULT TRUNC(SYSDATE)
) IS
  v_dev DATE;
BEGIN
  SELECT fecha_devolucion_real INTO v_dev
    FROM PrestamoLibro WHERE id_prestamo = p_prestamo
    FOR UPDATE;

  IF v_dev IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20004,'El préstamo ya fue devuelto');
  END IF;

  UPDATE PrestamoLibro
     SET fecha_devolucion_real = TRUNC(p_fecha)
   WHERE id_prestamo = p_prestamo;

  ---- Triggers ajustan estado y devuelven el ejemplar a 'disponible'
END;
/

--------------- Reservar Laptop (valida formato y no solape; el trigger también valida)
CREATE OR REPLACE PROCEDURE pr_reservar_laptop(
  p_usuario        IN  NUMBER,
  p_laptop         IN  NUMBER,
  p_fecha          IN  DATE,
  p_hora_inicio    IN  VARCHAR2,
  p_hora_fin       IN  VARCHAR2,
  p_bibliotecario  IN  NUMBER,
  p_id_reserva     OUT NUMBER
) IS
  v_est_usr VARCHAR2(15);
  v_est_lap VARCHAR2(15);
BEGIN
  ---- Normalizar horas a HH24:MI (si son válidas)
  --- Si son inválidas, fallará el TO_DATE y saltará error
  DECLARE
    v_hini VARCHAR2(5) := TO_CHAR(TO_DATE(p_hora_inicio,'HH24:MI'),'HH24:MI');
    v_hfin VARCHAR2(5) := TO_CHAR(TO_DATE(p_hora_fin,   'HH24:MI'),'HH24:MI');
  BEGIN
    --- Validación: inicio < fin
    IF fn_minutos(v_hini) >= fn_minutos(v_hfin) THEN
      RAISE_APPLICATION_ERROR(-20005,'hora_inicio debe ser menor que hora_fin');
    END IF;

    -- Validar usuario
    SELECT estado INTO v_est_usr FROM Usuario WHERE id_usuario = p_usuario;
    IF v_est_usr <> 'activo' THEN
      RAISE_APPLICATION_ERROR(-20006,'Usuario no está activo');
    END IF;
    IF fn_tiene_sancion_activa(p_usuario) = 1 THEN
      RAISE_APPLICATION_ERROR(-20007,'Usuario con sanción activa');
    END IF;

    --- Validar laptop (no dada de baja)
    SELECT estado INTO v_est_lap FROM Laptop WHERE id_laptop = p_laptop;
    IF v_est_lap = 'baja' THEN
      RAISE_APPLICATION_ERROR(-20008,'Laptop dada de baja');
    END IF;

    ---- Validar no solape (además del trigger)
    IF fn_reserva_solapa_laptop(p_laptop, TRUNC(p_fecha), v_hini, v_hfin, NULL) = 1 THEN
      RAISE_APPLICATION_ERROR(-20009,'Franja solapada con otra reserva activa');
    END IF;

    INSERT INTO ReservaLaptop(
      id_usuario, id_bibliotecario, id_laptop,
      fecha_solicitud, fecha_reserva, hora_inicio, hora_fin, estado
    ) VALUES (
      p_usuario, p_bibliotecario, p_laptop,
      SYSTIMESTAMP, TRUNC(p_fecha), v_hini, v_hfin, 'activa'
    )
    RETURNING id_reserva INTO p_id_reserva;
  END;
END;
/

------------------- Cancelar reserva de Laptop (si está activa)
CREATE OR REPLACE PROCEDURE pr_cancelar_reserva_laptop(p_reserva IN NUMBER) IS
  v_est VARCHAR2(15);
BEGIN
  SELECT estado INTO v_est FROM ReservaLaptop WHERE id_reserva = p_reserva FOR UPDATE;
  IF v_est <> 'activa' THEN
    RAISE_APPLICATION_ERROR(-20011,'Solo se pueden cancelar reservas activas');
  END IF;

  UPDATE ReservaLaptop SET estado = 'cancelada' WHERE id_reserva = p_reserva;
END;
/

----------------- Reservar Cubículo
CREATE OR REPLACE PROCEDURE pr_reservar_cubiculo(
  p_grupo          IN  NUMBER,
  p_cubiculo       IN  NUMBER,
  p_fecha          IN  DATE,
  p_hora_inicio    IN  VARCHAR2,
  p_hora_fin       IN  VARCHAR2,
  p_bibliotecario  IN  NUMBER,
  p_id_reserva     OUT NUMBER
) IS
  v_hini VARCHAR2(5);
  v_hfin VARCHAR2(5);
  v_est  VARCHAR2(15);
BEGIN
  v_hini := TO_CHAR(TO_DATE(p_hora_inicio,'HH24:MI'),'HH24:MI');
  v_hfin := TO_CHAR(TO_DATE(p_hora_fin,   'HH24:MI'),'HH24:MI');
  IF fn_minutos(v_hini) >= fn_minutos(v_hfin) THEN
    RAISE_APPLICATION_ERROR(-20012,'hora_inicio debe ser menor que hora_fin');
  END IF;

  SELECT estado INTO v_est FROM Cubiculo WHERE id_cubiculo = p_cubiculo;
  IF v_est = 'mantenimiento' THEN
    RAISE_APPLICATION_ERROR(-20013,'Cubículo en mantenimiento');
  END IF;

  IF fn_reserva_solapa_cubiculo(p_cubiculo, TRUNC(p_fecha), v_hini, v_hfin, NULL) = 1 THEN
    RAISE_APPLICATION_ERROR(-20014,'Franja solapada con otra reserva activa');
  END IF;

  INSERT INTO ReservaCubiculo(
    id_grupo_usuarios, id_bibliotecario, id_cubiculo,
    fecha_solicitud, fecha_reserva, hora_inicio, hora_fin, estado
  ) VALUES (
    p_grupo, p_bibliotecario, p_cubiculo,
    SYSTIMESTAMP, TRUNC(p_fecha), v_hini, v_hfin, 'activa'
  )
  RETURNING id_reserva INTO p_id_reserva;
END;
/

---------------- Cancelar reserva de Cubículo
CREATE OR REPLACE PROCEDURE pr_cancelar_reserva_cubiculo(p_reserva IN NUMBER) IS
  v_est VARCHAR2(15);
BEGIN
  SELECT estado INTO v_est FROM ReservaCubiculo WHERE id_reserva = p_reserva FOR UPDATE;
  IF v_est <> 'activa' THEN
    RAISE_APPLICATION_ERROR(-20015,'Solo se pueden cancelar reservas activas');
  END IF;

  UPDATE ReservaCubiculo SET estado = 'cancelada' WHERE id_reserva = p_reserva;
END;
/

--------------------------------- TRIGGERS --------------------------------------------

--------------- Normaliza HH:MI en ReservaLaptop
CREATE OR REPLACE TRIGGER trg_rl_normaliza_horas
BEFORE INSERT OR UPDATE OF hora_inicio, hora_fin ON ReservaLaptop
FOR EACH ROW
BEGIN
  :NEW.hora_inicio := TO_CHAR(TO_DATE(:NEW.hora_inicio,'HH24:MI'),'HH24:MI');
  :NEW.hora_fin    := TO_CHAR(TO_DATE(:NEW.hora_fin,   'HH24:MI'),'HH24:MI');
END;
/

--------------- Evita solapes y valida rango en ReservaLaptop
CREATE OR REPLACE TRIGGER trg_rl_no_solape
BEFORE INSERT OR UPDATE ON ReservaLaptop
FOR EACH ROW
BEGIN
  IF fn_minutos(:NEW.hora_inicio) IS NULL OR fn_minutos(:NEW.hora_fin) IS NULL THEN
    RAISE_APPLICATION_ERROR(-20016,'Formato de hora no válido (HH24:MI)');
  END IF;

  IF fn_minutos(:NEW.hora_inicio) >= fn_minutos(:NEW.hora_fin) THEN
    RAISE_APPLICATION_ERROR(-20017,'hora_inicio debe ser menor que hora_fin');
  END IF;

  IF fn_reserva_solapa_laptop(:NEW.id_laptop, :NEW.fecha_reserva, :NEW.hora_inicio, :NEW.hora_fin, :NEW.id_reserva) = 1 THEN
    RAISE_APPLICATION_ERROR(-20018,'La franja se solapa con otra reserva activa');
  END IF;
END;
/

--------------------- Normaliza HH:MI en ReservaCubiculo
CREATE OR REPLACE TRIGGER trg_rc_normaliza_horas
BEFORE INSERT OR UPDATE OF hora_inicio, hora_fin ON ReservaCubiculo
FOR EACH ROW
BEGIN
  :NEW.hora_inicio := TO_CHAR(TO_DATE(:NEW.hora_inicio,'HH24:MI'),'HH24:MI');
  :NEW.hora_fin    := TO_CHAR(TO_DATE(:NEW.hora_fin,   'HH24:MI'),'HH24:MI');
END;
/

--------------- Evita solapes y valida rango en ReservaCubiculo
CREATE OR REPLACE TRIGGER trg_rc_no_solape
BEFORE INSERT OR UPDATE ON ReservaCubiculo
FOR EACH ROW
BEGIN
  IF fn_minutos(:NEW.hora_inicio) IS NULL OR fn_minutos(:NEW.hora_fin) IS NULL THEN
    RAISE_APPLICATION_ERROR(-20019,'Formato de hora no válido (HH24:MI)');
  END IF;

  IF fn_minutos(:NEW.hora_inicio) >= fn_minutos(:NEW.hora_fin) THEN
    RAISE_APPLICATION_ERROR(-20020,'hora_inicio debe ser menor que hora_fin');
  END IF;

  IF fn_reserva_solapa_cubiculo(:NEW.id_cubiculo, :NEW.fecha_reserva, :NEW.hora_inicio, :NEW.hora_fin, :NEW.id_reserva) = 1 THEN
    RAISE_APPLICATION_ERROR(-20021,'La franja se solapa con otra reserva activa');
  END IF;
END;
/

------------------ Ajusta estado del préstamo según fechas (activo/atrasado/finalizado)
CREATE OR REPLACE TRIGGER trg_prestamo_ajusta_estado
BEFORE INSERT OR UPDATE OF fecha_inicio, fecha_fin, fecha_devolucion_real ON PrestamoLibro
FOR EACH ROW
BEGIN
  IF :NEW.fecha_devolucion_real IS NOT NULL THEN
    :NEW.estado := 'finalizado';
  ELSIF :NEW.fecha_fin IS NOT NULL AND TRUNC(SYSDATE) > :NEW.fecha_fin THEN
    :NEW.estado := 'atrasado';
  ELSE
    :NEW.estado := 'activo';
  END IF;
END;
/

----------------- Sincroniza estado del Ejemplar (prestado/disponible)
CREATE OR REPLACE TRIGGER trg_prestamo_sync_ejemplar
AFTER INSERT OR UPDATE OF fecha_devolucion_real ON PrestamoLibro
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    UPDATE Ejemplar SET estado = 'prestado'   WHERE id_ejemplar = :NEW.id_ejemplar;
  ELSIF UPDATING AND :NEW.fecha_devolucion_real IS NOT NULL AND :OLD.fecha_devolucion_real IS NULL THEN
    UPDATE Ejemplar SET estado = 'disponible' WHERE id_ejemplar = :NEW.id_ejemplar;
  END IF;
END;
/

----------------- Mantiene estado del Usuario según sanciones (activa => sancionado; sin activas => activo)
CREATE OR REPLACE TRIGGER trg_sancion_sync_usuario
AFTER INSERT OR UPDATE OR DELETE ON Sancion
FOR EACH ROW
DECLARE
  v_user NUMBER;
  v_activa NUMBER;
BEGIN
  IF INSERTING OR UPDATING THEN
    v_user := :NEW.id_usuario;
  ELSE
    v_user := :OLD.id_usuario;
  END IF;

  v_activa := fn_tiene_sancion_activa(v_user);

  IF v_activa = 1 THEN
    UPDATE Usuario SET estado='sancionado' WHERE id_usuario = v_user;
  ELSE
    UPDATE Usuario SET estado='activo' WHERE id_usuario = v_user AND estado='sancionado';
  END IF;
END;
/
