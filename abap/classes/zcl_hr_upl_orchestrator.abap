*&============================================================*
*& Class ZCL_HR_UPL_ORCHESTRATOR
*&============================================================*
*& Descripción: Coordinador principal del programa de        *
*& upload/carga de empleados desde archivo local              *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_upl_orchestrator DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.

    " Tipos
    TYPES:
      BEGIN OF gty_params,
        path          TYPE localfile,
        format        TYPE char4,        " XLSX, CSV
        mode          TYPE char1,        " N=Nuevos, R=Reemplazar, M=Merge
        simulation    TYPE abap_bool,
        del_tm        TYPE abap_bool,    " Borrar tablas TM
        commit_size   TYPE numc3,
        stop_on_error TYPE abap_bool,
      END OF gty_params.

    TYPES:
      BEGIN OF gty_result,
        pernr      TYPE pernr_d,
        status     TYPE char1,
        message    TYPE string,
        records_ok TYPE i,
        records_er TYPE i,
      END OF gty_result,
      gtt_results TYPE STANDARD TABLE OF gty_result.

    " Constructor
    METHODS constructor.

    " Ejecutar upload
    METHODS execute
      IMPORTING
        is_params  TYPE gty_params
      EXPORTING
        et_results TYPE gtt_results.

  PROTECTED SECTION.

    DATA:
      go_file_reader TYPE REF TO zcl_hr_upl_file_reader,
      go_parser      TYPE REF TO zcl_hr_upl_parser,
      go_replacer    TYPE REF TO zcl_hr_upl_replacer,
      go_validator   TYPE REF TO zcl_hr_upl_validator,
      go_logger      TYPE REF TO zcl_hr_upl_logger.

    " Leer archivo
    METHODS read_file
      IMPORTING
n        is_params       TYPE gty_params
      EXPORTING
        et_employees    TYPE zcl_hr_upl_parser=>gtt_employees
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    " Procesar un empleado
    METHODS process_employee
      IMPORTING
        is_employee    TYPE zcl_hr_upl_parser=>gty_employee
        is_params      TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

    " Modo NUEVOS: Solo insertar si no existe
    METHODS process_new
      IMPORTING
        is_employee    TYPE zcl_hr_upl_parser=>gty_employee
        is_params      TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

    " Modo REEMPLAZAR: Borrar + Insertar
    METHODS process_replace
      IMPORTING
        is_employee    TYPE zcl_hr_upl_parser=>gty_employee
        is_params      TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

    " Modo MERGE: Insertar solo faltantes
    METHODS process_merge
      IMPORTING
        is_employee    TYPE zcl_hr_upl_parser=>gty_employee
        is_params      TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

  PRIVATE SECTION.

    DATA:
      gv_processed TYPE i,
      gv_errors    TYPE i.

    CONSTANTS:
      gc_mode_new      TYPE char1 VALUE 'N',
      gc_mode_replace  TYPE char1 VALUE 'R',
      gc_mode_merge    TYPE char1 VALUE 'M'.

ENDCLASS.

CLASS zcl_hr_upl_orchestrator IMPLEMENTATION.

*--------------------------------------------------------------------*
* Constructor
*--------------------------------------------------------------------*
  METHOD constructor.

    go_file_reader = NEW zcl_hr_upl_file_reader( ).
    go_parser      = NEW zcl_hr_upl_parser( ).
    go_replacer    = NEW zcl_hr_upl_replacer( ).
    go_validator   = NEW zcl_hr_upl_validator( ).
    go_logger      = NEW zcl_hr_upl_logger( ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Ejecutar upload
*--------------------------------------------------------------------*
  METHOD execute.

    DATA: lt_employees TYPE zcl_hr_upl_parser=>gtt_employees,
          ls_result    TYPE gty_result.

    " Iniciar sesión de log
    go_logger->start_session( ).

    " Leer archivo
    IF read_file(
         EXPORTING is_params    = is_params
         IMPORTING et_employees = lt_employees
       ) = abap_false.
      APPEND VALUE #( status = 'E' message = 'Error leyendo archivo' ) TO et_results.
      RETURN.
    ENDIF.

    " Validar estructura
    IF go_validator->validate_structure( lt_employees ) = abap_false.
      APPEND VALUE #( status = 'E' message = 'Estructura de archivo inválida' ) TO et_results.
      RETURN.
    ENDIF.

    " Procesar cada empleado
    LOOP AT lt_employees INTO DATA(ls_employee).

      ls_result = process_employee(
        is_employee = ls_employee
        is_params   = is_params
      ).

      APPEND ls_result TO et_results.

      gv_processed = gv_processed + 1.

      IF ls_result-status = 'E'.
        gv_errors = gv_errors + 1.

        IF is_params-stop_on_error = abap_true.
          EXIT.
        ENDIF.
      ENDIF.

      " Commit cada N empleados
      IF is_params-simulation = abap_false AND
         is_params-commit_size > 0 AND
         gv_processed MOD is_params-commit_size = 0.
        COMMIT WORK.
      ENDIF.

    ENDLOOP.

    " Commit final
    IF is_params-simulation = abap_false.
      COMMIT WORK.
    ENDIF.

    " Finalizar sesión de log
    go_logger->end_session( ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Leer archivo
*--------------------------------------------------------------------*
  METHOD read_file.

    DATA: lt_raw_data TYPE STANDARD TABLE OF x255,
          lv_filesize TYPE i.

    " Leer archivo desde PC
    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = is_params-path
        filetype                = COND #( WHEN is_params-format = 'XLSX' THEN 'BIN' ELSE 'ASC' )
      IMPORTING
        filelength              = lv_filesize
      CHANGING
        data_tab                = lt_raw_data
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        unknown_error           = 7
        bad_data_format         = 8
        header_not_allowed      = 9
        separator_not_allowed   = 10
        header_too_long         = 11
        unknown_dp_error        = 12
        access_denied           = 13
        OTHERS                  = 14
    ).

    IF sy-subrc <> 0.
      rv_valid = abap_false.
      go_logger->log_error(
        iv_msg = |Error leyendo archivo: { sy-subrc }|
      ).
      RETURN.
    ENDIF.

    " Parsear según formato
    CASE is_params-format.
      WHEN 'XLSX'.
        rv_valid = go_parser->parse_excel(
          it_data      = lt_raw_data
          et_employees = et_employees
        ).

      WHEN 'CSV'.
        rv_valid = go_parser->parse_csv(
          it_data      = lt_raw_data
          et_employees = et_employees
        ).

      WHEN OTHERS.
        rv_valid = abap_false.
    ENDCASE.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Procesar empleado
*--------------------------------------------------------------------*
  METHOD process_employee.

    CASE is_params-mode.
      WHEN gc_mode_new.
        rs_result = process_new(
          is_employee = is_employee
          is_params   = is_params
        ).

      WHEN gc_mode_replace.
        rs_result = process_replace(
          is_employee = is_employee
          is_params   = is_params
        ).

      WHEN gc_mode_merge.
        rs_result = process_merge(
          is_employee = is_employee
          is_params   = is_params
        ).

      WHEN OTHERS.
        rs_result = VALUE #(
          pernr   = is_employee-pernr
          status  = 'E'
          message = |Modo inválido: { is_params-mode }|
        ).
    ENDCASE.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Procesar modo NUEVOS
*--------------------------------------------------------------------*
  METHOD process_new.

    " Verificar si empleado existe
    SELECT SINGLE pernr FROM pa0000
      INTO @DATA(lv_exists)
     WHERE pernr = @is_employee-pernr.

    IF sy-subrc = 0.
      rs_result = VALUE #(
        pernr   = is_employee-pernr
        status  = 'W'
        message = |Empleado { is_employee-pernr } ya existe - omitido|
      ).
      RETURN.
    ENDIF.

    " Insertar todos los infotipos
    DATA(lv_ok) = 0.
    DATA(lv_er) = 0.

    LOOP AT is_employee-infotypes INTO DATA(ls_infty).

      IF go_replacer->insert_infotype(
           iv_pernr = is_employee-pernr
           iv_infty = ls_infty-infty
           it_data  = ls_infty-records
           iv_simul = is_params-simulation
         ) = abap_true.
        lv_ok = lv_ok + 1.
      ELSE.
        lv_er = lv_er + 1.
      ENDIF.

    ENDLOOP.

    IF lv_er = 0.
      rs_result = VALUE #(
        pernr      = is_employee-pernr
        status     = 'S'
        message    = |Empleado nuevo creado exitosamente|
        records_ok = lv_ok
        records_er = lv_er
      ).
    ELSE.
      rs_result = VALUE #(
        pernr      = is_employee-pernr
        status     = 'E'
        message    = |Errores al crear empleado nuevo|
        records_ok = lv_ok
        records_er = lv_er
      ).
    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* Procesar modo REEMPLAZAR
*--------------------------------------------------------------------*
  METHOD process_replace.

    DATA: lv_ok TYPE i,
          lv_er TYPE i.

    " Verificar si empleado existe
    SELECT SINGLE pernr FROM pa0000
      INTO @DATA(lv_exists)
     WHERE pernr = @is_employee-pernr.

    IF sy-subrc <> 0.
      " Si no existe, tratar como nuevo
      rs_result = process_new(
        is_employee = is_employee
        is_params   = is_params
      ).
      RETURN.
    ENDIF.

    " Borrar todos los infotipos existentes
    IF go_replacer->delete_all_infotypes(
         iv_pernr = is_employee-pernr
         iv_del_tm = is_params-del_tm
         iv_simul = is_params-simulation
       ) = abap_false.
      rs_result = VALUE #(
        pernr   = is_employee-pernr
        status  = 'E'
        message = |Error borrando datos existentes|
      ).
      RETURN.
    ENDIF.

    " Insertar nuevos datos
    LOOP AT is_employee-infotypes INTO DATA(ls_infty).

      IF go_replacer->insert_infotype(
           iv_pernr = is_employee-pernr
           iv_infty = ls_infty-infty
           it_data  = ls_infty-records
           iv_simul = is_params-simulation
         ) = abap_true.
        lv_ok = lv_ok + 1.
      ELSE.
        lv_er = lv_er + 1.
      ENDIF.

    ENDLOOP.

    " Insertar tablas TM si aplica
    IF is_params-del_tm = abap_true.
      go_replacer->insert_ptquoded(
        iv_pernr = is_employee-pernr
        it_data  = is_employee-ptquoded
        iv_simul = is_params-simulation
      ).

      go_replacer->insert_teven(
        iv_pernr = is_employee-pernr
        it_data  = is_employee-teven
        iv_simul = is_params-simulation
      ).
    ENDIF.

    rs_result = VALUE #(
      pernr      = is_employee-pernr
      status     = COND #( WHEN lv_er = 0 THEN 'S' ELSE 'W' )
      message    = |Empleado reemplazado: { lv_ok } OK, { lv_er } errores|
      records_ok = lv_ok
      records_er = lv_er
    ).

  ENDMETHOD.

*--------------------------------------------------------------------*
* Procesar modo MERGE
*--------------------------------------------------------------------*
  METHOD process_merge.

    DATA: lv_ok TYPE i,
          lv_er TYPE i.

    LOOP AT is_employee-infotypes INTO DATA(ls_infty).

      " Verificar qué registros ya existen
      LOOP AT ls_infty-records INTO DATA(ls_record).

        IF go_replacer->record_exists(
             iv_pernr = is_employee-pernr
             iv_infty = ls_infty-infty
             is_key   = ls_record
           ) = abap_false.

          " Insertar solo si no existe
          IF go_replacer->insert_single_record(
               iv_pernr = is_employee-pernr
               iv_infty = ls_infty-infty
               is_data  = ls_record
               iv_simul = is_params-simulation
             ) = abap_true.
            lv_ok = lv_ok + 1.
          ELSE.
            lv_er = lv_er + 1.
          ENDIF.

        ENDIF.

      ENDLOOP.

    ENDLOOP.

    rs_result = VALUE #(
      pernr      = is_employee-pernr
      status     = COND #( WHEN lv_er = 0 THEN 'S' ELSE 'W' )
      message    = |Merge completado: { lv_ok } insertados, { lv_er } errores|
      records_ok = lv_ok
      records_er = lv_er
    ).

  ENDMETHOD.

ENDCLASS.