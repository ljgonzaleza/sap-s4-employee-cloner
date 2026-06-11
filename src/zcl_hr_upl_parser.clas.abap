*&============================================================*
*& Class ZCL_HR_UPL_PARSER
*&============================================================*
*& Descripción: Parser de archivos de carga (CSV/XLSX) a       *
*& estructura de empleados para upload                         *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_upl_parser DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: gtt_ptquoded TYPE STANDARD TABLE OF ptquoded WITH DEFAULT KEY.
    TYPES: gtt_teven    TYPE STANDARD TABLE OF teven WITH DEFAULT KEY.

    TYPES:
      BEGIN OF gty_infotype_data,
        infty   TYPE infty,
        records TYPE string_table,
      END OF gty_infotype_data,
      gtt_infotypes TYPE STANDARD TABLE OF gty_infotype_data WITH DEFAULT KEY.

    TYPES:
      BEGIN OF gty_employee,
        pernr     TYPE pernr_d,
        infotypes TYPE gtt_infotypes,
        ptquoded  TYPE gtt_ptquoded,
        teven     TYPE gtt_teven,
      END OF gty_employee,
      gtt_employees TYPE STANDARD TABLE OF gty_employee WITH DEFAULT KEY.

    METHODS parse_csv
      IMPORTING
        it_lines     TYPE string_table
      EXPORTING
        et_employees TYPE gtt_employees
        ev_valid     TYPE abap_bool.

    METHODS parse_excel
      IMPORTING
        iv_xstring   TYPE xstring
      EXPORTING
        et_employees TYPE gtt_employees
        ev_valid     TYPE abap_bool.

ENDCLASS.

CLASS zcl_hr_upl_parser IMPLEMENTATION.

  METHOD parse_csv.
    DATA: lv_pernr_txt TYPE string,
          lv_infty_txt TYPE string,
          lv_pernr     TYPE pernr_d,
          lv_infty     TYPE infty.

    FIELD-SYMBOLS: <ls_employee> TYPE gty_employee,
                   <ls_infotype> TYPE gty_infotype_data.

    CLEAR: et_employees, ev_valid.

    " Formato esperado: PERNR;INFTY;SEQNR;BEGDA;ENDDA;DATA
    LOOP AT it_lines INTO DATA(lv_line).
      " Saltar cabecera
      IF sy-tabix = 1 AND lv_line CS 'PERNR'.
        CONTINUE.
      ENDIF.

      IF lv_line IS INITIAL.
        CONTINUE.
      ENDIF.

      SPLIT lv_line AT ';' INTO lv_pernr_txt lv_infty_txt DATA(lv_rest).
      lv_pernr = lv_pernr_txt.
      lv_infty = lv_infty_txt.

      IF lv_pernr IS INITIAL.
        CONTINUE.
      ENDIF.

      " Buscar o crear empleado
      READ TABLE et_employees ASSIGNING <ls_employee>
        WITH KEY pernr = lv_pernr.
      IF sy-subrc <> 0.
        APPEND VALUE #( pernr = lv_pernr ) TO et_employees ASSIGNING <ls_employee>.
      ENDIF.

      " Buscar o crear grupo de infotipo
      READ TABLE <ls_employee>-infotypes ASSIGNING <ls_infotype>
        WITH KEY infty = lv_infty.
      IF sy-subrc <> 0.
        APPEND VALUE #( infty = lv_infty ) TO <ls_employee>-infotypes ASSIGNING <ls_infotype>.
      ENDIF.

      APPEND lv_line TO <ls_infotype>-records.
    ENDLOOP.

    ev_valid = xsdbool( et_employees IS NOT INITIAL ).
  ENDMETHOD.

  METHOD parse_excel.
    CLEAR: et_employees, ev_valid.

    " Pendiente: parseo nativo XLSX (requiere ABAP2XLSX u OpenXML).
    " Exportar en CSV desde el clonador mientras tanto.
    ev_valid = abap_false.
  ENDMETHOD.

ENDCLASS.
