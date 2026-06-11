*&============================================================*
*& Class ZCL_HR_CLN_ITYPE_BASE
*&============================================================*
*& Descripción: Clase base abstracta para handlers de infotipos*
*& del clonador de empleados SAP S/4HANA                      *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_cln_itype_base DEFINITION PUBLIC ABSTRACT CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      gc_status_success TYPE char1 VALUE 'S',
      gc_status_warning TYPE char1 VALUE 'W',
      gc_status_error   TYPE char1 VALUE 'E'.

    TYPES:
      BEGIN OF gty_result,
        status  TYPE char1,
        message TYPE string,
        pernr   TYPE pernr_d,
        infty   TYPE infty,
        seqnr   TYPE seqnr,
      END OF gty_result.

    TYPES: gtt_results TYPE STANDARD TABLE OF gty_result WITH DEFAULT KEY.

    TYPES:
      BEGIN OF gty_seqnr_map,
        infty     TYPE infty,
        seqnr_src TYPE seqnr,
        seqnr_tgt TYPE seqnr,
      END OF gty_seqnr_map,
      gtt_seqnr_map TYPE HASHED TABLE OF gty_seqnr_map
        WITH UNIQUE KEY infty seqnr_src.

    METHODS constructor
      IMPORTING
        io_logger TYPE REF TO zcl_hr_cln_logger OPTIONAL.

    METHODS clone ABSTRACT
      IMPORTING
        iv_pernr_src TYPE pernr_d
        iv_pernr_tgt TYPE pernr_d
        is_params    TYPE zhr_cln_params
      EXPORTING
        et_results   TYPE gtt_results
        et_seqnr_map TYPE gtt_seqnr_map.

    " Métodos de instancia: los estáticos no pueden redefinirse
    METHODS supports_infty
      IMPORTING
        iv_infty            TYPE infty
      RETURNING
        VALUE(rv_supported) TYPE abap_bool.

    METHODS get_infty
      RETURNING
        VALUE(rv_infty) TYPE infty.

  PROTECTED SECTION.

    DATA: go_logger TYPE REF TO zcl_hr_cln_logger.

    METHODS read_source
      IMPORTING
        iv_pernr TYPE pernr_d
        iv_infty TYPE infty
      EXPORTING
        et_data  TYPE STANDARD TABLE.

    METHODS validate_record
      IMPORTING
        is_data         TYPE any
        is_params       TYPE zhr_cln_params
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS transform_record
      IMPORTING
        is_data      TYPE any
        iv_pernr_tgt TYPE pernr_d
        is_params    TYPE zhr_cln_params
      CHANGING
        cs_data      TYPE any.

    " RETURNING no se combina con EXPORTING: ambos por EXPORTING
    METHODS write_target
      IMPORTING
        iv_infty TYPE infty
        is_data  TYPE any
        iv_mode  TYPE actio DEFAULT 'INS'
      EXPORTING
        ev_seqnr TYPE seqnr
        ev_subrc TYPE sysubrc.

    METHODS clean_technical_fields
      CHANGING
        cs_data TYPE any.

    METHODS apply_date_shift
      IMPORTING
        iv_shift_days TYPE i
      CHANGING
        cs_data       TYPE any.

  PRIVATE SECTION.

    CLASS-DATA: gt_exclude_fields TYPE STANDARD TABLE OF fieldname WITH DEFAULT KEY.

    CLASS-METHODS initialize_exclude_fields.

ENDCLASS.

CLASS zcl_hr_cln_itype_base IMPLEMENTATION.

  METHOD constructor.
    go_logger = io_logger.
    initialize_exclude_fields( ).
  ENDMETHOD.

  METHOD supports_infty.
    rv_supported = abap_false.
  ENDMETHOD.

  METHOD get_infty.
    CLEAR rv_infty.
  ENDMETHOD.

  METHOD initialize_exclude_fields.
    IF gt_exclude_fields IS INITIAL.
      gt_exclude_fields = VALUE #(
        ( 'PERNR' )
        ( 'AEDTM' )
        ( 'UNAME' )
        ( 'HISTO' )
        ( 'REPID' )
        ( 'SEQNR' )
      ).
    ENDIF.
  ENDMETHOD.

  METHOD read_source.
    DATA(lv_tabname) = |PA{ iv_infty }|.

    " En sintaxis estricta INTO va al final
    SELECT * FROM (lv_tabname)
     WHERE pernr = @iv_pernr
     ORDER BY begda
      INTO TABLE @et_data.

    IF sy-subrc <> 0.
      IF go_logger IS BOUND.
        go_logger->log_warning(
          iv_pernr_src = iv_pernr
          iv_infty     = iv_infty
          iv_msg       = |No se encontraron registros para PERNR { iv_pernr }|
        ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD validate_record.
    rv_valid = abap_true.

    ASSIGN COMPONENT 'BEGDA' OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_begda>).
    IF sy-subrc = 0 AND <lv_begda> IS INITIAL.
      rv_valid = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD transform_record.
    clean_technical_fields( CHANGING cs_data = cs_data ).

    ASSIGN COMPONENT 'PERNR' OF STRUCTURE cs_data TO FIELD-SYMBOL(<fs_tgt>).
    IF sy-subrc = 0.
      <fs_tgt> = iv_pernr_tgt.
    ENDIF.

    IF is_params-date_shift <> 0.
      apply_date_shift(
        EXPORTING iv_shift_days = is_params-date_shift
        CHANGING  cs_data       = cs_data
      ).
    ENDIF.
  ENDMETHOD.

  METHOD write_target.
    DATA: lt_return TYPE STANDARD TABLE OF bapiret2,
          ls_key    TYPE bapipakey,
          lv_pernr  TYPE pernr_d,
          lv_subty  TYPE subty,
          lv_endda  TYPE endda,
          lv_begda  TYPE begda.

    CLEAR: ev_seqnr, ev_subrc.

    " Leer campos clave dinámicamente de is_data para evitar type conflict o dump
    ASSIGN COMPONENT 'PERNR' OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_pernr>).
    IF sy-subrc = 0.
      lv_pernr = <lv_pernr>.
    ENDIF.

    ASSIGN COMPONENT 'SUBTY' OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_subty>).
    IF sy-subrc = 0.
      lv_subty = <lv_subty>.
    ENDIF.

    ASSIGN COMPONENT 'ENDDA' OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_endda>).
    IF sy-subrc = 0.
      lv_endda = <lv_endda>.
    ENDIF.

    ASSIGN COMPONENT 'BEGDA' OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_begda>).
    IF sy-subrc = 0.
      lv_begda = <lv_begda>.
    ENDIF.

    CALL FUNCTION 'HR_INFOTYPE_OPERATION'
      EXPORTING
        infty         = iv_infty
        number        = lv_pernr
        subtype       = lv_subty
        objectid      = space
        lockindicator = space
        validityend   = lv_endda
        validitybegin = lv_begda
        recordnumber  = '000'
        record        = is_data
        operation     = iv_mode
        nocommit      = abap_true
      IMPORTING
        key           = ls_key
      TABLES
        return        = lt_return.

    " Leer SEQNR dinámicamente: la estructura BAPIPAKEY varía entre releases
    ASSIGN COMPONENT 'SEQNR' OF STRUCTURE ls_key TO FIELD-SYMBOL(<lv_seqnr>).
    IF sy-subrc = 0.
      ev_seqnr = <lv_seqnr>.
    ENDIF.

    READ TABLE lt_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
    ev_subrc = COND #( WHEN sy-subrc = 0 THEN 4 ELSE 0 ).
  ENDMETHOD.

  METHOD clean_technical_fields.
    FIELD-SYMBOLS: <fs_field> TYPE any.

    LOOP AT gt_exclude_fields INTO DATA(lv_field).
      ASSIGN COMPONENT lv_field OF STRUCTURE cs_data TO <fs_field>.
      IF sy-subrc = 0.
        CLEAR <fs_field>.
      ENDIF.
    ENDLOOP.

    ASSIGN COMPONENT 'AEDTM' OF STRUCTURE cs_data TO <fs_field>.
    IF sy-subrc = 0.
      <fs_field> = sy-datum.
    ENDIF.

    ASSIGN COMPONENT 'UNAME' OF STRUCTURE cs_data TO <fs_field>.
    IF sy-subrc = 0.
      <fs_field> = sy-uname.
    ENDIF.
  ENDMETHOD.

  METHOD apply_date_shift.
    FIELD-SYMBOLS: <lv_date> TYPE d.

    ASSIGN COMPONENT 'BEGDA' OF STRUCTURE cs_data TO <lv_date>.
    IF sy-subrc = 0 AND <lv_date> IS NOT INITIAL.
      <lv_date> = <lv_date> + iv_shift_days.
    ENDIF.

    ASSIGN COMPONENT 'ENDDA' OF STRUCTURE cs_data TO <lv_date>.
    IF sy-subrc = 0 AND <lv_date> IS NOT INITIAL
       AND <lv_date> <> '99991231'.
      <lv_date> = <lv_date> + iv_shift_days.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
