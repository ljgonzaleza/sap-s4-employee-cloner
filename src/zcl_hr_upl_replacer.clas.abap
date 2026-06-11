*&============================================================*
*& Class ZCL_HR_UPL_REPLACER
*&============================================================*
*& Descripción: Inserción y borrado de infotipos y tablas TM   *
*& para el programa de upload                                  *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_upl_replacer DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    " Insertar registros de un infotipo a partir de sus XMLs serializados
    METHODS insert_infotype
      IMPORTING
        iv_pernr     TYPE pernr_d
        iv_infty     TYPE infty
        it_xml_recs  TYPE string_table
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    " Borrar todos los registros de todos los infotipos de un PERNR
    METHODS delete_all_infotypes
      IMPORTING
        iv_pernr     TYPE pernr_d
        iv_del_tm    TYPE abap_bool DEFAULT abap_false
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    " Insertar registros TEVEN desde XMLs serializados
    METHODS insert_teven_from_xml
      IMPORTING
        iv_pernr     TYPE pernr_d
        it_xml_recs  TYPE string_table
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    " Insertar registros PTQUODED desde XMLs serializados
    METHODS insert_ptquoded_from_xml
      IMPORTING
        iv_pernr     TYPE pernr_d
        it_xml_recs  TYPE string_table
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

  PRIVATE SECTION.

    " Deserializar XML a estructura dinámica y llamar HR_INFOTYPE_OPERATION
    METHODS write_infotype_record
      IMPORTING
        iv_infty     TYPE infty
        iv_xml       TYPE string
        iv_simul     TYPE abap_bool
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    " Leer lista de infotipos con datos para un PERNR (tabla T582A)
    METHODS get_infoty_list_for_pernr
      IMPORTING
        iv_pernr      TYPE pernr_d
      RETURNING
        VALUE(rt_list) TYPE STANDARD TABLE.

ENDCLASS.

CLASS zcl_hr_upl_replacer IMPLEMENTATION.

  METHOD insert_infotype.
    rv_ok = abap_true.
    LOOP AT it_xml_recs INTO DATA(lv_xml).
      IF write_infotype_record( iv_infty = iv_infty iv_xml = lv_xml iv_simul = iv_simul ) = abap_false.
        rv_ok = abap_false.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD write_infotype_record.
    DATA: lo_rec    TYPE REF TO data,
          lv_pernr  TYPE pernr_d,
          lv_subty  TYPE subty,
          lv_begda  TYPE begda,
          lv_endda  TYPE endda.

    rv_ok = abap_false.

    TRY.
        " Crear estructura dinámica del tipo de infotipo (P0001, P0002 ...)
        DATA(lv_type) = |P{ iv_infty }|.
        CREATE DATA lo_rec TYPE (lv_type).
        FIELD-SYMBOLS <ls_rec> TYPE any.
        ASSIGN lo_rec->* TO <ls_rec>.

        " Deserializar XML al registro
        DATA(lv_xstring) = cl_abap_codepage=>convert_to( source = iv_xml codepage = 'UTF-8' ).
        CALL TRANSFORMATION id
          SOURCE XML lv_xstring
          RESULT data = <ls_rec>.

        " Leer campos clave dinámicamente
        ASSIGN COMPONENT 'PERNR' OF STRUCTURE <ls_rec> TO FIELD-SYMBOL(<f>).
        IF sy-subrc = 0. lv_pernr = <f>. ENDIF.
        ASSIGN COMPONENT 'SUBTY' OF STRUCTURE <ls_rec> TO <f>.
        IF sy-subrc = 0. lv_subty = <f>. ENDIF.
        ASSIGN COMPONENT 'BEGDA' OF STRUCTURE <ls_rec> TO <f>.
        IF sy-subrc = 0. lv_begda = <f>. ENDIF.
        ASSIGN COMPONENT 'ENDDA' OF STRUCTURE <ls_rec> TO <f>.
        IF sy-subrc = 0. lv_endda = <f>. ENDIF.

        IF lv_pernr IS INITIAL.
          RETURN.
        ENDIF.

        IF iv_simul = abap_true.
          rv_ok = abap_true.
          RETURN.
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
            record        = <ls_rec>
            operation     = 'INS'
            nocommit      = abap_true
          EXCEPTIONS
            infty_not_found = 1
            unknown_error   = 2
            locked_by_other = 3
            internal_error  = 4
            OTHERS          = 5.

        rv_ok = xsdbool( sy-subrc = 0 ).
      CATCH cx_root.
        rv_ok = abap_false.
    ENDTRY.
  ENDMETHOD.

  METHOD delete_all_infotypes.
    rv_ok = abap_true.

    IF iv_simul = abap_true.
      RETURN.
    ENDIF.

    " Leer infotipos con registros para este PERNR desde T582A
    SELECT DISTINCT infty
      FROM t582a
      WHERE infty BETWEEN '0000' AND '9999'
      INTO TABLE @DATA(lt_infty).

    LOOP AT lt_infty INTO DATA(lv_infty).
      DATA(lv_table) = |PA{ lv_infty }|.

      TRY.
          " Leer registros existentes
          DATA lo_data TYPE REF TO data.
          CREATE DATA lo_data TYPE STANDARD TABLE OF (lv_table).
          FIELD-SYMBOLS <lt_recs> TYPE STANDARD TABLE.
          ASSIGN lo_data->* TO <lt_recs>.

          SELECT * FROM (lv_table)
            WHERE pernr = @iv_pernr
            INTO CORRESPONDING FIELDS OF TABLE @<lt_recs>.

          LOOP AT <lt_recs> ASSIGNING FIELD-SYMBOL(<ls_rec>).
            DATA lv_subty  TYPE subty.
            DATA lv_begda  TYPE begda.
            DATA lv_endda  TYPE endda.
            DATA lv_seqnr  TYPE pa_seqnr.

            ASSIGN COMPONENT 'SUBTY' OF STRUCTURE <ls_rec> TO FIELD-SYMBOL(<f>). IF sy-subrc = 0. lv_subty = <f>. ENDIF.
            ASSIGN COMPONENT 'BEGDA' OF STRUCTURE <ls_rec> TO <f>. IF sy-subrc = 0. lv_begda = <f>. ENDIF.
            ASSIGN COMPONENT 'ENDDA' OF STRUCTURE <ls_rec> TO <f>. IF sy-subrc = 0. lv_endda = <f>. ENDIF.
            ASSIGN COMPONENT 'SEQNR' OF STRUCTURE <ls_rec> TO <f>. IF sy-subrc = 0. lv_seqnr = <f>. ENDIF.

            CALL FUNCTION 'HR_INFOTYPE_OPERATION'
              EXPORTING
                infty         = lv_infty
                number        = iv_pernr
                subtype       = lv_subty
                validityend   = lv_endda
                validitybegin = lv_begda
                recordnumber  = lv_seqnr
                record        = <ls_rec>
                operation     = 'DEL'
                nocommit      = abap_true
              EXCEPTIONS
                OTHERS        = 5.
          ENDLOOP.
        CATCH cx_root.
      ENDTRY.
    ENDLOOP.

    IF iv_del_tm = abap_true.
      DELETE FROM teven   WHERE pernr = @iv_pernr.
      DELETE FROM ptquoded WHERE pernr = @iv_pernr.
    ENDIF.
  ENDMETHOD.

  METHOD insert_teven_from_xml.
    rv_ok = abap_true.

    IF iv_simul = abap_true.
      RETURN.
    ENDIF.

    LOOP AT it_xml_recs INTO DATA(lv_xml).
      TRY.
          DATA(lv_xstr) = cl_abap_codepage=>convert_to( source = lv_xml codepage = 'UTF-8' ).
          DATA ls_teven TYPE teven.
          CALL TRANSFORMATION id SOURCE XML lv_xstr RESULT data = ls_teven.
          ls_teven-pernr = iv_pernr.
          INSERT teven FROM ls_teven.
          IF sy-subrc <> 0. rv_ok = abap_false. ENDIF.
        CATCH cx_root.
          rv_ok = abap_false.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD insert_ptquoded_from_xml.
    rv_ok = abap_true.

    IF iv_simul = abap_true.
      RETURN.
    ENDIF.

    LOOP AT it_xml_recs INTO DATA(lv_xml).
      TRY.
          DATA(lv_xstr) = cl_abap_codepage=>convert_to( source = lv_xml codepage = 'UTF-8' ).
          DATA ls_ptq TYPE ptquoded.
          CALL TRANSFORMATION id SOURCE XML lv_xstr RESULT data = ls_ptq.
          ls_ptq-pernr = iv_pernr.
          INSERT ptquoded FROM ls_ptq.
          IF sy-subrc <> 0. rv_ok = abap_false. ENDIF.
        CATCH cx_root.
          rv_ok = abap_false.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_infoty_list_for_pernr.
  ENDMETHOD.

ENDCLASS.
