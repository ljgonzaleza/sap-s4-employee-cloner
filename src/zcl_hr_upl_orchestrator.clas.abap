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

CLASS zcl_hr_upl_orchestrator DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF gty_params,
        path          TYPE localfile,
        format        TYPE char4,
        mode          TYPE char1,
        simulation    TYPE abap_bool,
        del_tm        TYPE abap_bool,
        commit_size   TYPE numc3,
        stop_on_error TYPE abap_bool,
        cluster_path  TYPE localfile,
      END OF gty_params.

    TYPES:
      BEGIN OF gty_result,
        pernr      TYPE pernr_d,
        status     TYPE char1,
        message    TYPE string,
        records_ok TYPE i,
        records_er TYPE i,
      END OF gty_result,
      gtt_results TYPE STANDARD TABLE OF gty_result WITH DEFAULT KEY.

    METHODS constructor.

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

    " RETURNING no se combina con EXPORTING: todo por EXPORTING
    METHODS read_file
      IMPORTING
        is_params    TYPE gty_params
      EXPORTING
        et_employees TYPE zcl_hr_upl_parser=>gtt_employees
        ev_valid     TYPE abap_bool.

    METHODS process_employee
      IMPORTING
        is_employee      TYPE zcl_hr_upl_parser=>gty_employee
        is_params        TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

    METHODS process_new
      IMPORTING
        is_employee      TYPE zcl_hr_upl_parser=>gty_employee
        is_params        TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

    METHODS process_replace
      IMPORTING
        is_employee      TYPE zcl_hr_upl_parser=>gty_employee
        is_params        TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

    METHODS process_merge
      IMPORTING
        is_employee      TYPE zcl_hr_upl_parser=>gty_employee
        is_params        TYPE gty_params
      RETURNING
        VALUE(rs_result) TYPE gty_result.

  PRIVATE SECTION.

    DATA: gv_processed TYPE i,
          gv_errors    TYPE i.

    CONSTANTS:
      gc_mode_new     TYPE char1 VALUE 'N',
      gc_mode_replace TYPE char1 VALUE 'R',
      gc_mode_merge   TYPE char1 VALUE 'M'.

ENDCLASS.

CLASS zcl_hr_upl_orchestrator IMPLEMENTATION.

  METHOD constructor.
    go_file_reader = NEW zcl_hr_upl_file_reader( ).
    go_parser      = NEW zcl_hr_upl_parser( ).
    go_replacer    = NEW zcl_hr_upl_replacer( ).
    go_validator   = NEW zcl_hr_upl_validator( ).
    go_logger      = NEW zcl_hr_upl_logger( ).
  ENDMETHOD.

  METHOD execute.
    DATA: lt_employees  TYPE zcl_hr_upl_parser=>gtt_employees,
          ls_result     TYPE gty_result,
          lv_valid      TYPE abap_bool,
          lt_clus_lines TYPE string_table,
          lv_clus_valid TYPE abap_bool.

    CLEAR et_results.

    go_logger->start_session( ).

    " Leer archivo principal de infotipos
    read_file(
      EXPORTING is_params    = is_params
      IMPORTING et_employees = lt_employees
                ev_valid     = lv_valid
    ).

    IF lv_valid = abap_false.
      APPEND VALUE #( status = 'E' message = 'Error leyendo archivo' ) TO et_results.
      RETURN.
    ENDIF.

    IF go_validator->validate_structure( lt_employees ) = abap_false.
      APPEND VALUE #( status = 'E' message = 'Estructura de archivo inválida' ) TO et_results.
      RETURN.
    ENDIF.

    " Si se indicó archivo de clusters, enriquecer la estructura de empleados
    IF is_params-cluster_path IS NOT INITIAL.
      go_file_reader->read_csv(
        EXPORTING iv_path  = is_params-cluster_path
        IMPORTING et_lines = lt_clus_lines
                  ev_valid = lv_clus_valid
      ).
      IF lv_clus_valid = abap_true.
        go_parser->parse_clusters(
          EXPORTING it_lines     = lt_clus_lines
          CHANGING  ct_employees = lt_employees
        ).
      ELSE.
        go_logger->log_error( iv_msg = |No se pudo leer archivo de clusters: { is_params-cluster_path }| ).
      ENDIF.
    ENDIF.

    LOOP AT lt_employees INTO DATA(ls_employee).
      ls_result = process_employee( is_employee = ls_employee is_params = is_params ).
      APPEND ls_result TO et_results.
      gv_processed = gv_processed + 1.

      IF ls_result-status = 'E'.
        gv_errors = gv_errors + 1.
        IF is_params-stop_on_error = abap_true.
          EXIT.
        ENDIF.
      ENDIF.

      IF is_params-simulation = abap_false AND
         is_params-commit_size > 0 AND
         gv_processed MOD is_params-commit_size = 0.
        COMMIT WORK.
      ENDIF.
    ENDLOOP.

    IF is_params-simulation = abap_false.
      COMMIT WORK.
    ENDIF.

    go_logger->end_session( ).
  ENDMETHOD.

  METHOD read_file.
    DATA: lt_lines    TYPE string_table,
          lv_xstring  TYPE xstring.

    CLEAR: et_employees, ev_valid.

    CASE is_params-format.
      WHEN 'CSV'.
        go_file_reader->read_csv(
          EXPORTING iv_path  = is_params-path
          IMPORTING et_lines = lt_lines
                    ev_valid = ev_valid
        ).

        IF ev_valid = abap_true.
          go_parser->parse_csv(
            EXPORTING it_lines     = lt_lines
            IMPORTING et_employees = et_employees
                      ev_valid     = ev_valid
          ).
        ELSE.
          go_logger->log_error( iv_msg = |Error leyendo archivo CSV| ).
        ENDIF.

      WHEN 'XLSX'.
        go_file_reader->read_binary(
          EXPORTING iv_path    = is_params-path
          IMPORTING ev_xstring = lv_xstring
                    ev_valid   = ev_valid
        ).

        IF ev_valid = abap_true.
          go_parser->parse_excel(
            EXPORTING iv_xstring   = lv_xstring
            IMPORTING et_employees = et_employees
                      ev_valid     = ev_valid
          ).
        ELSE.
          go_logger->log_error( iv_msg = |Error leyendo archivo XLSX| ).
        ENDIF.

      WHEN OTHERS.
        ev_valid = abap_false.
    ENDCASE.
  ENDMETHOD.

  METHOD process_employee.
    CASE is_params-mode.
      WHEN gc_mode_new.
        rs_result = process_new( is_employee = is_employee is_params = is_params ).
      WHEN gc_mode_replace.
        rs_result = process_replace( is_employee = is_employee is_params = is_params ).
      WHEN gc_mode_merge.
        rs_result = process_merge( is_employee = is_employee is_params = is_params ).
      WHEN OTHERS.
        rs_result = VALUE #(
          pernr   = is_employee-pernr
          status  = 'E'
          message = |Modo inválido: { is_params-mode }|
        ).
    ENDCASE.
  ENDMETHOD.

  METHOD process_new.
    DATA: lv_ok TYPE i,
          lv_er TYPE i.

    SELECT SINGLE pernr
      FROM pa0000
     WHERE pernr = @is_employee-pernr
      INTO @DATA(lv_exists).

    IF sy-subrc = 0.
      rs_result = VALUE #(
        pernr   = is_employee-pernr
        status  = 'W'
        message = |Empleado { is_employee-pernr } ya existe - omitido|
      ).
      RETURN.
    ENDIF.

    " Insertar infotipos (registros en formato XML serializado)
    LOOP AT is_employee-infotypes INTO DATA(ls_infty).
      IF go_replacer->insert_infotype(
           iv_pernr    = is_employee-pernr
           iv_infty    = ls_infty-infty
           it_xml_recs = ls_infty-records
           iv_simul    = is_params-simulation ) = abap_true.
        lv_ok = lv_ok + 1.
      ELSE.
        lv_er = lv_er + 1.
      ENDIF.
    ENDLOOP.

    " Insertar TEVEN, PTQUODED y clusters si vienen en el archivo
    IF is_employee-teven_xml IS NOT INITIAL.
      go_replacer->insert_teven_from_xml(
        iv_pernr    = is_employee-pernr
        it_xml_recs = is_employee-teven_xml
        iv_simul    = is_params-simulation ).
    ENDIF.
    IF is_employee-ptquoded_xml IS NOT INITIAL.
      go_replacer->insert_ptquoded_from_xml(
        iv_pernr    = is_employee-pernr
        it_xml_recs = is_employee-ptquoded_xml
        iv_simul    = is_params-simulation ).
    ENDIF.
    IF is_employee-pcl1_xml IS NOT INITIAL.
      go_replacer->insert_pcl1_from_xml(
        it_xml_recs = is_employee-pcl1_xml
        iv_simul    = is_params-simulation ).
    ENDIF.
    IF is_employee-pcl2_xml IS NOT INITIAL.
      go_replacer->insert_pcl2_from_xml(
        it_xml_recs = is_employee-pcl2_xml
        iv_simul    = is_params-simulation ).
    ENDIF.

    rs_result = VALUE #(
      pernr      = is_employee-pernr
      records_ok = lv_ok
      records_er = lv_er
      status     = COND #( WHEN lv_er = 0 THEN 'S' ELSE 'E' )
      message    = COND #( WHEN lv_er = 0
                           THEN |Empleado cargado exitosamente|
                           ELSE |Errores al cargar empleado| )
    ).
  ENDMETHOD.

  METHOD process_replace.
    DATA: lv_ok TYPE i,
          lv_er TYPE i.

    " Borrar datos existentes (infotipos + TM si se indica)
    IF go_replacer->delete_all_infotypes(
         iv_pernr  = is_employee-pernr
         iv_del_tm = is_params-del_tm
         iv_simul  = is_params-simulation ) = abap_false.
      rs_result = VALUE #(
        pernr   = is_employee-pernr
        status  = 'E'
        message = |Error borrando datos existentes|
      ).
      RETURN.
    ENDIF.

    " Insertar nuevos registros
    LOOP AT is_employee-infotypes INTO DATA(ls_infty).
      IF go_replacer->insert_infotype(
           iv_pernr    = is_employee-pernr
           iv_infty    = ls_infty-infty
           it_xml_recs = ls_infty-records
           iv_simul    = is_params-simulation ) = abap_true.
        lv_ok = lv_ok + 1.
      ELSE.
        lv_er = lv_er + 1.
      ENDIF.
    ENDLOOP.

    IF is_employee-teven_xml IS NOT INITIAL.
      go_replacer->insert_teven_from_xml(
        iv_pernr    = is_employee-pernr
        it_xml_recs = is_employee-teven_xml
        iv_simul    = is_params-simulation ).
    ENDIF.
    IF is_employee-ptquoded_xml IS NOT INITIAL.
      go_replacer->insert_ptquoded_from_xml(
        iv_pernr    = is_employee-pernr
        it_xml_recs = is_employee-ptquoded_xml
        iv_simul    = is_params-simulation ).
    ENDIF.
    IF is_employee-pcl1_xml IS NOT INITIAL.
      go_replacer->insert_pcl1_from_xml(
        it_xml_recs = is_employee-pcl1_xml
        iv_simul    = is_params-simulation ).
    ENDIF.
    IF is_employee-pcl2_xml IS NOT INITIAL.
      go_replacer->insert_pcl2_from_xml(
        it_xml_recs = is_employee-pcl2_xml
        iv_simul    = is_params-simulation ).
    ENDIF.

    rs_result = VALUE #(
      pernr      = is_employee-pernr
      records_ok = lv_ok
      records_er = lv_er
      status     = COND #( WHEN lv_er = 0 THEN 'S' ELSE 'W' )
      message    = |Empleado reemplazado: { lv_ok } OK, { lv_er } errores|
    ).
  ENDMETHOD.

  METHOD process_merge.
    DATA: lv_ok TYPE i,
          lv_er TYPE i.

    " En merge: solo insertar infotipos que no existan aún
    LOOP AT is_employee-infotypes INTO DATA(ls_infty).
      DATA(lv_table) = |PA{ ls_infty-infty }|.
      SELECT SINGLE pernr FROM (lv_table)
        WHERE pernr = @is_employee-pernr
        INTO @DATA(lv_exists_pernr).

      IF sy-subrc <> 0.
        " Infotipo no existe: insertar todos sus registros
        IF go_replacer->insert_infotype(
             iv_pernr    = is_employee-pernr
             iv_infty    = ls_infty-infty
             it_xml_recs = ls_infty-records
             iv_simul    = is_params-simulation ) = abap_true.
          lv_ok = lv_ok + 1.
        ELSE.
          lv_er = lv_er + 1.
        ENDIF.
      ENDIF.
    ENDLOOP.

    rs_result = VALUE #(
      pernr      = is_employee-pernr
      records_ok = lv_ok
      records_er = lv_er
      status     = COND #( WHEN lv_er = 0 THEN 'S' ELSE 'W' )
      message    = |Merge completado: { lv_ok } infotipos insertados, { lv_er } errores|
    ).
  ENDMETHOD.

ENDCLASS.
