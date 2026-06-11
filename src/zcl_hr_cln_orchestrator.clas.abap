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

    TYPES:
      BEGIN OF gty_params,
        pernr_src    TYPE r_pernr,
        pernr_tgt    TYPE r_pernr,
        bukrs        TYPE bukrs,
        werks        TYPE persa,
        btrtl        TYPE btrtl,
        copy_hist    TYPE abap_bool,
        simulation   TYPE abap_bool,
        overwrite    TYPE abap_bool,
        date_shift   TYPE i,
        itype_from   TYPE infty,
        itype_to     TYPE infty,
        country      TYPE land1,
        incl_tm      TYPE abap_bool,
        export_local TYPE abap_bool,
        exp_path     TYPE localfile,
        exp_format   TYPE char4,
        exp_split    TYPE abap_bool,
      END OF gty_params.

    TYPES:
      BEGIN OF gty_result,
        pernr_src TYPE pernr_d,
        pernr_tgt TYPE pernr_d,
        status    TYPE char1,
        message   TYPE string,
      END OF gty_result,
      gtt_results TYPE STANDARD TABLE OF gty_result.

    METHODS constructor.

    METHODS execute
      IMPORTING
        is_params      TYPE gty_params
      EXPORTING
        et_results     TYPE gtt_results
        ev_export_path TYPE string.

    METHODS validate_params
      IMPORTING
        is_params       TYPE gty_params
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS get_infotype_list
      IMPORTING
        is_params       TYPE gty_params
      RETURNING
        VALUE(rt_infty) TYPE STANDARD TABLE OF infty.

  PROTECTED SECTION.

    DATA: go_logger    TYPE REF TO zcl_hr_cln_logger,
          go_exporter  TYPE REF TO zcl_hr_cln_exporter,
          gt_handlers  TYPE STANDARD TABLE OF REF TO zcl_hr_cln_itype_base.

    METHODS initialize_handlers.

    METHODS process_employee
      IMPORTING
        iv_pernr_src TYPE pernr_d
        iv_pernr_tgt TYPE pernr_d
        is_params    TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

    METHODS determine_target_pernr
      IMPORTING
        iv_pernr_src TYPE pernr_d
        is_params    TYPE gty_params
      RETURNING
        VALUE(rv_pernr_tgt) TYPE pernr_d.

    METHODS check_authorizations
      IMPORTING
        iv_pernr TYPE pernr_d
      RETURNING
        VALUE(rv_authorized) TYPE abap_bool.

  PRIVATE SECTION.

    DATA: gv_clone_id TYPE sysuuid_x16.

ENDCLASS.

CLASS zcl_hr_cln_orchestrator IMPLEMENTATION.

  METHOD constructor.
    go_logger   = NEW zcl_hr_cln_logger( ).
    go_exporter = NEW zcl_hr_cln_exporter( io_logger = go_logger ).
    initialize_handlers( ).

    TRY.
        gv_clone_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        gv_clone_id = '0000000000000000'.
    ENDTRY.
  ENDMETHOD.

  METHOD initialize_handlers.
    DATA: lo_handler TYPE REF TO zcl_hr_cln_itype_base.

    lo_handler = NEW zcl_hr_cln_itype_0002( go_logger ).
    APPEND lo_handler TO gt_handlers.
  ENDMETHOD.

  METHOD execute.
    DATA: lt_results TYPE gtt_results,
          ls_result  TYPE gty_result,
          lv_export_path TYPE string.

    go_logger->start_session( gv_clone_id ).

    IF validate_params( is_params ) = abap_false.
      APPEND VALUE #( status = 'E' message = 'Parámetros inválidos' ) TO lt_results.
      et_results = lt_results.
      RETURN.
    ENDIF.

    LOOP AT is_params-pernr_src ASSIGNING FIELD-SYMBOL(<lv_pernr>).
      IF check_authorizations( <lv_pernr> ) = abap_false.
        go_logger->log_error(
          iv_pernr_src = <lv_pernr>
          iv_msg       = |Sin autorización para PERNR { <lv_pernr> }|
        ).
        CONTINUE.
      ENDIF.

      DATA(lv_pernr_tgt) = determine_target_pernr( iv_pernr_src = <lv_pernr> is_params = is_params ).
      ls_result = process_employee( iv_pernr_src = <lv_pernr> iv_pernr_tgt = lv_pernr_tgt is_params = is_params ).
      APPEND ls_result TO lt_results.
    ENDLOOP.

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

    go_logger->end_session( iv_save = abap_true ).
    et_results = lt_results.
  ENDMETHOD.

  METHOD validate_params.
    rv_valid = abap_true.

    IF is_params-pernr_src IS INITIAL.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    IF is_params-itype_from IS NOT INITIAL AND
       is_params-itype_to IS NOT INITIAL AND
       is_params-itype_from > is_params-itype_to.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    IF is_params-export_local = abap_true AND
       is_params-exp_format NOT IN ('XLSX', 'CSV', 'JSON').
      rv_valid = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD get_infotype_list.
    DATA: lt_infty TYPE STANDARD TABLE OF infty.

    lt_infty = VALUE #(
      ( '0000' ) ( '0001' ) ( '0002' ) ( '0006' )
      ( '0007' ) ( '0008' ) ( '0009' ) ( '0014' )
      ( '0015' ) ( '0016' ) ( '0021' )
    ).

    IF is_params-incl_tm = abap_true.
      APPEND '2001' TO lt_infty.
      APPEND '2006' TO lt_infty.
      APPEND '2011' TO lt_infty.
    ENDIF.

    IF is_params-itype_from IS NOT INITIAL.
      DELETE lt_infty WHERE table_line < is_params-itype_from.
    ENDIF.
    IF is_params-itype_to IS NOT INITIAL.
      DELETE lt_infty WHERE table_line > is_params-itype_to.
    ENDIF.

    rt_infty = lt_infty.
  ENDMETHOD.

  METHOD process_employee.
    DATA: lt_handler_results TYPE zcl_hr_cln_itype_base=>gtt_results,
          ls_params_local    TYPE zhr_cln_params.

    ls_params_local = CORRESPONDING #( is_params ).

    go_logger->log_info(
      iv_pernr_src = iv_pernr_src
      iv_pernr_tgt = iv_pernr_tgt
      iv_msg       = |Iniciando clonación { iv_pernr_src } → { iv_pernr_tgt }|
    ).

    LOOP AT gt_handlers INTO DATA(lo_handler).
      lo_handler->clone(
        EXPORTING
          iv_pernr_src = iv_pernr_src
          iv_pernr_tgt = iv_pernr_tgt
          is_params    = ls_params_local
        IMPORTING
          et_results   = lt_handler_results
      ).

      READ TABLE lt_handler_results TRANSPORTING NO FIELDS
        WITH KEY status = zcl_hr_cln_itype_base=>gc_status_error.
      IF sy-subrc = 0.
        rs_result-status = 'E'.
      ENDIF.
    ENDLOOP.

    rs_result-pernr_src = iv_pernr_src.
    rs_result-pernr_tgt = iv_pernr_tgt.

    IF rs_result-status IS INITIAL.
      rs_result-status  = 'S'.
      rs_result-message = |Clonación exitosa: { iv_pernr_src } → { iv_pernr_tgt }|.
    ELSE.
      rs_result-message = |Clonación con errores: { iv_pernr_src } → { iv_pernr_tgt }|.
    ENDIF.
  ENDMETHOD.

  METHOD determine_target_pernr.
    rv_pernr_tgt = COND #( WHEN is_params-pernr_tgt IS NOT INITIAL
                            THEN is_params-pernr_tgt
                            ELSE iv_pernr_src ).
  ENDMETHOD.

  METHOD check_authorizations.
    AUTHORITY-CHECK OBJECT 'P_PERNR'
      ID 'PERNR' FIELD iv_pernr
      ID 'ACTVT' FIELD '03'.

    rv_authorized = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.

ENDCLASS.
