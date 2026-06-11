*&============================================================*
*& Class ZCL_HR_CLN_ITYPE_0002
*&============================================================*
*& Descripción: Handler para infotipo 0002 (Datos Personales)  *
*& del clonador de empleados SAP S/4HANA                       *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_cln_itype_0002 DEFINITION
  INHERITING FROM zcl_hr_cln_itype_base
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-DATA: gc_infty TYPE infty VALUE '0002' READ-ONLY.

    METHODS constructor
      IMPORTING
        io_logger TYPE REF TO zcl_hr_cln_logger OPTIONAL.

    METHODS clone REDEFINITION.
    CLASS-METHODS supports_infty REDEFINITION.
    CLASS-METHODS get_infty REDEFINITION.

  PROTECTED SECTION.

    CONSTANTS:
      gc_field_cpf TYPE fieldname VALUE 'CPFNR',
      gc_field_ced TYPE fieldname VALUE 'ICNUM'.

    METHODS clean_personal_ids
      IMPORTING
        is_params TYPE zhr_cln_params
      CHANGING
        cs_data   TYPE p0002.

    METHODS generate_dummy_id
      IMPORTING
        iv_prefix   TYPE string
        iv_original TYPE string
      RETURNING
        VALUE(rv_dummy) TYPE string.

ENDCLASS.

CLASS zcl_hr_cln_itype_0002 IMPLEMENTATION.

  METHOD constructor.
    super->constructor( io_logger ).
  ENDMETHOD.

  METHOD supports_infty.
    rv_supported = xsdbool( iv_infty = gc_infty ).
  ENDMETHOD.

  METHOD get_infty.
    rv_infty = gc_infty.
  ENDMETHOD.

  METHOD clone.
    DATA: lt_source TYPE STANDARD TABLE OF p0002,
          ls_target TYPE p0002,
          ls_result TYPE gty_result.

    FIELD-SYMBOLS: <ls_source> TYPE p0002.

    SELECT * FROM pa0002
      INTO TABLE @lt_source
     WHERE pernr = @iv_pernr_src
     ORDER BY begda.

    IF sy-subrc <> 0.
      APPEND VALUE #(
        status  = gc_status_warning
        message = |No se encontraron registros IT 0002 para PERNR { iv_pernr_src }|
        pernr   = iv_pernr_tgt
        infty   = gc_infty
      ) TO et_results.
      RETURN.
    ENDIF.

    LOOP AT lt_source ASSIGNING <ls_source>.

      IF validate_record( is_data = <ls_source> is_params = is_params ) = abap_false.
        CONTINUE.
      ENDIF.

      ls_target = <ls_source>.

      transform_record(
        EXPORTING is_data = <ls_source> iv_pernr_tgt = iv_pernr_tgt is_params = is_params
        CHANGING  cs_data = ls_target
      ).

      clean_personal_ids( EXPORTING is_params = is_params CHANGING cs_data = ls_target ).

      IF is_params-simulation = abap_false.

        DATA(lv_subrc) = write_target(
          EXPORTING
            iv_infty = gc_infty
            is_data  = ls_target
            iv_mode  = COND #( WHEN is_params-overwrite = abap_true THEN 'MOD' ELSE 'INS' )
          IMPORTING
            ev_seqnr = ls_result-seqnr
        ).

        IF lv_subrc = 0.
          ls_result-status  = gc_status_success.
          ls_result-message = |IT 0002 clonado exitosamente SEQNR { ls_result-seqnr }|.
          APPEND VALUE #( infty = gc_infty seqnr_src = <ls_source>-seqnr seqnr_tgt = ls_result-seqnr ) TO et_seqnr_map.
        ELSE.
          ls_result-status  = gc_status_error.
          ls_result-message = |Error al clonar IT 0002 SEQNR { <ls_source>-seqnr }|.
        ENDIF.

      ELSE.
        ls_result-status  = gc_status_success.
        ls_result-message = |Simulación: IT 0002 listo para clonar SEQNR { <ls_source>-seqnr }|.
      ENDIF.

      ls_result-pernr = iv_pernr_tgt.
      ls_result-infty = gc_infty.
      APPEND ls_result TO et_results.

      IF go_logger IS BOUND.
        go_logger->log_success(
          iv_pernr_src = iv_pernr_src  iv_pernr_tgt = iv_pernr_tgt
          iv_infty     = gc_infty      iv_seqnr     = <ls_source>-seqnr
          iv_msg       = ls_result-message
        ).
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD clean_personal_ids.
    DATA: lv_mode TYPE char1.

    SELECT SINGLE uniq_cpf_mode FROM zhr_cln_config INTO @lv_mode WHERE mandt = @sy-mandt.
    IF sy-subrc <> 0.
      lv_mode = 'L'.
    ENDIF.

    ASSIGN COMPONENT 'CPFNR' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_cpf>).
    IF sy-subrc = 0 AND <lv_cpf> IS NOT INITIAL.
      CASE lv_mode.
        WHEN 'L'. CLEAR <lv_cpf>.
        WHEN 'G'. <lv_cpf> = generate_dummy_id( iv_prefix = '999' iv_original = <lv_cpf> ).
      ENDCASE.
    ENDIF.

    ASSIGN COMPONENT 'ICNUM' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_icnum>).
    IF sy-subrc = 0 AND <lv_icnum> IS NOT INITIAL.
      CASE lv_mode.
        WHEN 'L'. CLEAR <lv_icnum>.
        WHEN 'G'. <lv_icnum> = generate_dummy_id( iv_prefix = '999' iv_original = <lv_icnum> ).
      ENDCASE.
    ENDIF.

    ASSIGN COMPONENT 'USRID_LONG' OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_email>).
    IF sy-subrc = 0 AND <lv_email> IS NOT INITIAL.
      <lv_email> = |employee{ cs_data-pernr }@company.com|.
    ENDIF.
  ENDMETHOD.

  METHOD generate_dummy_id.
    rv_dummy = |{ iv_prefix }{ sy-datum+2(6) }{ sy-uzeit(4) }|.
  ENDMETHOD.

ENDCLASS.
