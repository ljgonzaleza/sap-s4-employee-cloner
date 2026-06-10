*&============================================================*
*& Class ZCL_HR_CLN_ORCHESTRATOR
*&============================================================*
*& Descripción: Coordinador principal del clonador de          *
*& empleados SAP S/4HANA                                       *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_cln_orchestrator DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.

    " Tipos
    TYPES:
      BEGIN OF gty_params,
        pernr_src    TYPE r_pernr,     " Rango PERNR origen
        pernr_tgt    TYPE r_pernr,     " Rango PERNR destino
        bukrs        TYPE bukrs,       " Sociedad
        werks        TYPE persa,       " División personal
        btrtl        TYPE btrtl,       " Subdivisión
        copy_hist    TYPE abap_bool,   " Copiar histórico
        simulation   TYPE abap_bool,   " Modo simulación
        overwrite    TYPE abap_bool,   " Sobrescribir
        date_shift   TYPE i,           " Desplazamiento fechas
        itype_from   TYPE infty,       " Rango infotipos desde
        itype_to     TYPE infty,       " Rango infotipos hasta
        country      TYPE land1,       " Filtrar país
        incl_tm      TYPE abap_bool,   " Incluir Time Management
        export_local TYPE abap_bool,   " Exportar a archivo local
        exp_path     TYPE localfile,   " Ruta exportación
        exp_format   TYPE char4,       " Formato: XLSX, CSV
        exp_split    TYPE abap_bool,   " Archivo separado por empleado
      END OF gty_params.

    TYPES:
      BEGIN OF gty_result,
        pernr_src TYPE pernr_d,
        pernr_tgt TYPE pernr_d,
        status    TYPE char1,
        message   TYPE string,
      END OF gty_result,
      gtt_results TYPE STANDARD TABLE OF gty_result.

    " Constructor
    METHODS constructor.

    " Ejecutar clonación
    METHODS execute
      IMPORTING
n        is_params       TYPE gty_params
      EXPORTING
        et_results      TYPE gtt_results
        ev_export_path  TYPE string.

    " Validar parámetros
    METHODS validate_params
      IMPORTING
        is_params        TYPE gty_params
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    " Obtener lista de infotipos a procesar
    METHODS get_infotype_list
      IMPORTING
        is_params       TYPE gty_params
      RETURNING
        VALUE(rt_infty) TYPE STANDARD TABLE OF infty.

  PROTECTED SECTION.

    DATA: go_logger    TYPE REF TO zcl_hr_cln_logger,
          go_exporter  TYPE REF TO zcl_hr_cln_exporter,
          gt_handlers  TYPE STANDARD TABLE OF REF TO zcl_hr_cln_itype_base.

    " Inicializar handlers
    METHODS initialize_handlers.

    " Procesar un empleado
    METHODS process_employee
      IMPORTING
        iv_pernr_src TYPE pernr_d
        iv_pernr_tgt TYPE pernr_d
        is_params    TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

    " Determinar PERNR destino
    METHODS determine_target_pernr
      IMPORTING
        iv_pernr_src TYPE pernr_d
        is_params    TYPE gty_params
      RETURNING
        VALUE(rv_pernr_tgt) TYPE pernr_d.

    " Verificar autorizaciones
    METHODS check_authorizations
      IMPORTING
        iv_pernr TYPE pernr_d
      RETURNING
        VALUE(rv_authorized) TYPE abap_bool.

  PRIVATE SECTION.

    DATA: gv_clone_id TYPE sysuuid_x16.

    " Constantes
    CONSTANTS:
      gc_infty_core TYPE STANDARD TABLE OF infty WITH DEFAULT KEY
        VALUE #( ( '0000' ) ( '0001' ) ( '0002' ) ( '0006' )
                 ( '0007' ) ( '0008' ) ( '0009' ) ( '0014' )
                 ( '0015' ) ( '0016' ) ( '0021' ) ).

ENDCLASS.

CLASS zcl_hr_cln_orchestrator IMPLEMENTATION.

*--------------------------------------------------------------------*
* Constructor
*--------------------------------------------------------------------*
  METHOD constructor.

    " Crear logger
    go_logger = NEW zcl_hr_cln_logger( ).

    " Crear exporter
    go_exporter = NEW zcl_hr_cln_exporter( io_logger = go_logger ).

    " Inicializar handlers
    initialize_handlers( ).

    " Generar ID de clonación
    TRY.
        gv_clone_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        gv_clone_id = '0000000000000000'.
    ENDTRY.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Inicializar handlers
*--------------------------------------------------------------------*
  METHOD initialize_handlers.

    " Crear instancias de handlers para infotipos core
    DATA: lo_handler TYPE REF TO zcl_hr_cln_itype_base.

    " Handler para IT 0000 (Acciones)
    lo_handler = NEW zcl_hr_cln_itype_0000( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0001 (Asignación organizativa)
    lo_handler = NEW zcl_hr_cln_itype_0001( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0002 (Datos personales)
    lo_handler = NEW zcl_hr_cln_itype_0002( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0006 (Direcciones)
    lo_handler = NEW zcl_hr_cln_itype_0006( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0007 (Planificación tiempos)
    lo_handler = NEW zcl_hr_cln_itype_0007( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0008 (Remuneración básica)
    lo_handler = NEW zcl_hr_cln_itype_0008( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0009 (Datos bancarios)
    lo_handler = NEW zcl_hr_cln_itype_0009( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0014 (Pagos recurrentes)
    lo_handler = NEW zcl_hr_cln_itype_0014( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0015 (Pagos adicionales)
    lo_handler = NEW zcl_hr_cln_itype_0015( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0016 (Contrato)
    lo_handler = NEW zcl_hr_cln_itype_0016( go_logger ).
    APPEND lo_handler TO gt_handlers.

    " Handler para IT 0021 (Familiares)
    lo_handler = NEW zcl_hr_cln_itype_0021( go_logger ).
    APPEND lo_handler TO gt_handlers.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Ejecutar clonación
*--------------------------------------------------------------------*
  METHOD execute.

    DATA: lt_results TYPE gtt_results,
          ls_result  TYPE gty_result.

    DATA: lv_export_path TYPE string.

    " Iniciar sesión de log
    go_logger->start_session( gv_clone_id ).

    " Validar parámetros
    IF validate_params( is_params ) = abap_false.
      APPEND VALUE #( status = 'E' message = 'Parámetros inválidos' ) TO lt_results.
      et_results = lt_results.
      RETURN.
    ENDIF.

    " Verificar autorizaciones
    LOOP AT is_params-pernr_src ASSIGNING FIELD-SYMBOL(<lv_pernr>).
      IF check_authorizations( <lv_pernr> ) = abap_false.
        go_logger->log_error(
          iv_pernr_src = <lv_pernr>
          iv_msg       = |Sin autorización para PERNR { <lv_pernr> }|
        ).
        CONTINUE.
      ENDIF.

      " Determinar PERNR destino
      DATA(lv_pernr_tgt) = determine_target_pernr(
        iv_pernr_src = <lv_pernr>
        is_params    = is_params
      ).

      " Procesar empleado
      ls_result = process_employee(
        iv_pernr_src = <lv_pernr>
        iv_pernr_tgt = lv_pernr_tgt
        is_params    = is_params
      ).

      APPEND ls_result TO lt_results.

    ENDLOOP.

    " Exportar a archivo local si se solicita
    IF is_params-export_local = abap_true.
      go_exporter->export_to_file(
        EXPORTING
          it_results   = lt_results
          iv_format    = is_params-exp_format
          iv_path      = is_params-exp_path
          iv_split     = is_params-exp_split
        IMPORTING
          ev_file_path = lv_export_path
      ).
      ev_export_path = lv_export_path.
    ENDIF.

    " Finalizar sesión de log
    go_logger->end_session( iv_save = abap_true ).

    et_results = lt_results.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Validar parámetros
*--------------------------------------------------------------------*
  METHOD validate_params.

    rv_valid = abap_true.

    " Validar que hay PERNR origen
    IF is_params-pernr_src IS INITIAL.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    " Validar rango de infotipos
    IF is_params-itype_from IS NOT INITIAL AND
       is_params-itype_to IS NOT INITIAL AND
       is_params-itype_from > is_params-itype_to.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    " Validar formato exportación
    IF is_params-export_local = abap_true.
      IF is_params-exp_format NOT IN ('XLSX', 'CSV', 'JSON').
        rv_valid = abap_false.
        RETURN.
      ENDIF.
    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Obtener lista de infotipos
*--------------------------------------------------------------------*
  METHOD get_infotype_list.

    DATA: lt_infty TYPE STANDARD TABLE OF infty.

    " Infotipos core siempre incluidos
    lt_infty = gc_infty_core.

    " Agregar Time Management si se solicita
    IF is_params-incl_tm = abap_true.
      APPEND '2001' TO lt_infty.
      APPEND '2006' TO lt_infty.
      APPEND '2011' TO lt_infty.
    ENDIF.

    " Filtrar por rango si se especifica
    IF is_params-itype_from IS NOT INITIAL.
      DELETE lt_infty WHERE table_line < is_params-itype_from.
    ENDIF.

    IF is_params-itype_to IS NOT INITIAL.
      DELETE lt_infty WHERE table_line > is_params-itype_to.
    ENDIF.

    rt_infty = lt_infty.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Procesar un empleado
*--------------------------------------------------------------------*
  METHOD process_employee.

    DATA: lt_handler_results TYPE zcl_hr_cln_itype_base=>gtt_results,
          ls_params_local    TYPE zhr_cln_params.

    " Preparar parámetros para handlers
    ls_params_local = CORRESPONDING #( is_params ).

    " Loguear inicio de procesamiento
    go_logger->log_info(
      iv_pernr_src = iv_pernr_src
      iv_pernr_tgt = iv_pernr_tgt
      iv_msg       = |Iniciando clonación { iv_pernr_src } → { iv_pernr_tgt }|
    ).

    " Procesar cada handler
    LOOP AT gt_handlers INTO DATA(lo_handler).

      lo_handler->clone(
        EXPORTING
          iv_pernr_src = iv_pernr_src
          iv_pernr_tgt = iv_pernr_tgt
          is_params    = ls_params_local
        IMPORTING
          et_results   = lt_handler_results
      ).

      " Verificar resultados
      LOOP AT lt_handler_results TRANSPORTING NO FIELDS
        WHERE status = zcl_hr_cln_itype_base=>gc_status_error.
        rs_result-status = 'E'.
      ENDLOOP.

    ENDLOOP.

    " Determinar resultado final
    IF rs_result-status IS INITIAL.
      rs_result-status = 'S'.
      rs_result-message = |Clonación exitosa: { iv_pernr_src } → { iv_pernr_tgt }|.
    ELSE.
      rs_result-message = |Clonación con errores: { iv_pernr_src } → { iv_pernr_tgt }|.
    ENDIF.

    rs_result-pernr_src = iv_pernr_src.
    rs_result-pernr_tgt = iv_pernr_tgt.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Determinar PERNR destino
*--------------------------------------------------------------------*
  METHOD determine_target_pernr.

    IF is_params-pernr_tgt IS NOT INITIAL.
      " Si se especifica PERNR destino, usarlo
      rv_pernr_tgt = is_params-pernr_tgt.
    ELSE.
      " Generar nuevo PERNR (lógica específica del cliente)
      " Por ahora, retornar el mismo (modo simulación)
      rv_pernr_tgt = iv_pernr_src.
    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Verificar autorizaciones
*--------------------------------------------------------------------*
  METHOD check_authorizations.

    DATA: lv_subrc TYPE sysubrc.

    " Verificar autorización para PERNR
    AUTHORITY-CHECK OBJECT 'P_PERNR'
      ID 'PERNR' FIELD iv_pernr
      ID 'ACTVT' FIELD '03'.

    lv_subrc = sy-subrc.

    IF lv_subrc <> 0.
      rv_authorized = abap_false.
    ELSE.
      rv_authorized = abap_true.
    ENDIF.

  ENDMETHOD.

ENDCLASS.