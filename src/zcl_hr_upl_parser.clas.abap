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
        pernr        TYPE pernr_d,
        infotypes    TYPE gtt_infotypes,
        ptquoded     TYPE gtt_ptquoded,
        teven        TYPE gtt_teven,
        teven_xml    TYPE string_table,
        ptquoded_xml TYPE string_table,
        pcl1_xml     TYPE string_table,
        pcl2_xml     TYPE string_table,
      END OF gty_employee,
      gtt_employees TYPE STANDARD TABLE OF gty_employee WITH DEFAULT KEY.

    METHODS parse_csv
      IMPORTING
        it_lines     TYPE string_table
      EXPORTING
        et_employees TYPE gtt_employees
        ev_valid     TYPE abap_bool.

    " Parseo del archivo separado de clusters (PCL1/PCL2)
    METHODS parse_clusters
      IMPORTING
        it_lines     TYPE string_table
      CHANGING
        ct_employees TYPE gtt_employees.

    METHODS parse_excel
      IMPORTING
        iv_xstring   TYPE xstring
      EXPORTING
        et_employees TYPE gtt_employees
        ev_valid     TYPE abap_bool.

ENDCLASS.

CLASS zcl_hr_upl_parser IMPLEMENTATION.

  METHOD parse_csv.
    " Formato del exportador: TYPE|INFTY|PERNR|SUBTY|BEGDA|ENDDA|SEQNR|XML_DATA
    DATA: lv_type  TYPE string,
          lv_infty TYPE infty,
          lv_pernr TYPE pernr_d,
          lv_subty TYPE string,
          lv_begda TYPE string,
          lv_endda TYPE string,
          lv_seqnr TYPE string,
          lv_xml   TYPE string.

    FIELD-SYMBOLS: <ls_employee> TYPE gty_employee,
                   <ls_infotype> TYPE gty_infotype_data.

    CLEAR: et_employees, ev_valid.

    LOOP AT it_lines INTO DATA(lv_line).
      " Ignorar líneas vacías y cabeceras (empiezan con #)
      IF lv_line IS INITIAL OR lv_line(1) = '#'.
        CONTINUE.
      ENDIF.

      " Separador pipe |
      SPLIT lv_line AT '|' INTO lv_type lv_infty lv_pernr lv_subty lv_begda lv_endda lv_seqnr lv_xml.

      IF lv_pernr IS INITIAL OR lv_xml IS INITIAL.
        CONTINUE.
      ENDIF.

      " Buscar o crear empleado
      READ TABLE et_employees ASSIGNING <ls_employee> WITH KEY pernr = lv_pernr.
      IF sy-subrc <> 0.
        APPEND VALUE #( pernr = lv_pernr ) TO et_employees ASSIGNING <ls_employee>.
      ENDIF.

      CASE lv_type.
        WHEN 'PA'.
          " Registros de infotipos PA
          READ TABLE <ls_employee>-infotypes ASSIGNING <ls_infotype> WITH KEY infty = lv_infty.
          IF sy-subrc <> 0.
            APPEND VALUE #( infty = lv_infty ) TO <ls_employee>-infotypes ASSIGNING <ls_infotype>.
          ENDIF.
          APPEND lv_xml TO <ls_infotype>-records.

        WHEN 'TEVEN'.
          " Registros de tabla TEVEN (serializados como XML)
          APPEND lv_xml TO <ls_employee>-teven_xml.

        WHEN 'PTQUODED'.
          " Registros de tabla PTQUODED (serializados como XML)
          APPEND lv_xml TO <ls_employee>-ptquoded_xml.
      ENDCASE.
    ENDLOOP.

    ev_valid = xsdbool( et_employees IS NOT INITIAL ).
  ENDMETHOD.

  METHOD parse_clusters.
    " Parseo del archivo CLONE_CLUSTERS_*.dat generado por ZCL_HR_CLN_EXPORTER.
    " Formato: TYPE|TABLE|PERNR|RELID|SEQNO|FPPER|XML_DATA
    DATA: lv_type   TYPE string,
          lv_table  TYPE string,
          lv_pernr  TYPE pernr_d,
          lv_relid  TYPE string,
          lv_seqno  TYPE string,
          lv_fpper  TYPE string,
          lv_xml    TYPE string.

    FIELD-SYMBOLS: <ls_emp> TYPE gty_employee.

    LOOP AT it_lines INTO DATA(lv_line).
      IF lv_line IS INITIAL OR lv_line(1) = '#'.
        CONTINUE.
      ENDIF.

      SPLIT lv_line AT '|' INTO lv_type lv_table lv_pernr lv_relid lv_seqno lv_fpper lv_xml.

      IF lv_pernr IS INITIAL OR lv_xml IS INITIAL.
        CONTINUE.
      ENDIF.

      READ TABLE ct_employees ASSIGNING <ls_emp> WITH KEY pernr = lv_pernr.
      IF sy-subrc <> 0.
        APPEND VALUE #( pernr = lv_pernr ) TO ct_employees ASSIGNING <ls_emp>.
      ENDIF.

      CASE lv_type.
        WHEN 'PCL1'.
          APPEND lv_xml TO <ls_emp>-pcl1_xml.
        WHEN 'PCL2'.
          APPEND lv_xml TO <ls_emp>-pcl2_xml.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD parse_excel.
    CLEAR: et_employees, ev_valid.

    " Pendiente: parseo nativo XLSX (requiere ABAP2XLSX u OpenXML).
    " Exportar en CSV desde el clonador mientras tanto.
    ev_valid = abap_false.
  ENDMETHOD.

ENDCLASS.
