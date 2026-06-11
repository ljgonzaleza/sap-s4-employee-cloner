*&============================================================*
*& Class ZCL_HR_CLN_EXPORTER
*&============================================================*
*& Descripción: Exportador de datos clonados a archivo local   *
*& (Excel/CSV) para análisis offline o carga en otro ambiente  *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_cln_exporter DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    " Cabecera del archivo de exportación (primer campo de cada línea)
    CONSTANTS: gc_sect_pa      TYPE string VALUE 'PA',
               gc_sect_teven   TYPE string VALUE 'TEVEN',
               gc_sect_ptquod  TYPE string VALUE 'PTQUODED',
               gc_file_sep     TYPE string VALUE '|'.

    METHODS constructor
      IMPORTING
        io_logger TYPE REF TO zcl_hr_cln_logger OPTIONAL.

    TYPES: gtt_pernrs TYPE STANDARD TABLE OF pernr_d WITH DEFAULT KEY.

    " Exportación completa de datos reales para carga en otro sistema/mandante
    METHODS export_pernrs_to_file
      IMPORTING
        it_pernrs    TYPE gtt_pernrs
        iv_format    TYPE char4      DEFAULT 'CSV'
        iv_path      TYPE localfile  OPTIONAL
        iv_split     TYPE abap_bool  DEFAULT abap_false
      EXPORTING
        ev_file_path TYPE string.

    CLASS-METHODS download_to_pc
      IMPORTING
        iv_filename TYPE string
        iv_data     TYPE xstring
      EXPORTING
        ev_path     TYPE string.

  PROTECTED SECTION.

    DATA: go_logger TYPE REF TO zcl_hr_cln_logger.

    " Leer TODOS los infotipos, TEVEN y PTQUODED de un PERNR y devolver líneas del archivo
    METHODS read_pernr_all_data
      IMPORTING
        iv_pernr  TYPE pernr_d
      EXPORTING
        et_lines  TYPE string_table.

    " Serializar cualquier estructura ABAP a XML de una línea (sin saltos de carro)
    METHODS serialize_record
      IMPORTING
        is_data        TYPE any
      RETURNING
        VALUE(rv_xml)  TYPE string.

    METHODS get_default_path
      RETURNING
        VALUE(rv_path) TYPE string.

ENDCLASS.

CLASS zcl_hr_cln_exporter IMPLEMENTATION.

  METHOD constructor.
    go_logger = io_logger.
  ENDMETHOD.

  METHOD export_pernrs_to_file.
    DATA: lt_all_lines TYPE string_table,
          lt_pernr_lines TYPE string_table,
          lv_dir       TYPE string,
          lv_filename  TYPE string,
          lv_pernr     TYPE pernr_d.

    " Normalizar directorio base
    IF iv_path IS NOT INITIAL.
      lv_dir = iv_path.
    ELSE.
      lv_dir = get_default_path( ).
    ENDIF.

    DATA(lv_len) = strlen( lv_dir ).
    IF lv_len > 0.
      DATA(lv_off) = lv_len - 1.
      DATA(lv_last) = lv_dir+lv_off(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        lv_dir = lv_dir && `\`.
      ENDIF.
    ENDIF.

    " Cabecera del archivo
    APPEND |#CLONER_EXPORT{ gc_file_sep }VERSION{ gc_file_sep }1.0{ gc_file_sep }DATE{ gc_file_sep }{ sy-datum }{ gc_file_sep }TIME{ gc_file_sep }{ sy-uzeit }|
      TO lt_all_lines.
    APPEND |#TYPE{ gc_file_sep }INFTY{ gc_file_sep }PERNR{ gc_file_sep }SUBTY{ gc_file_sep }BEGDA{ gc_file_sep }ENDDA{ gc_file_sep }SEQNR{ gc_file_sep }XML_DATA|
      TO lt_all_lines.

    LOOP AT it_pernrs INTO lv_pernr.

      CLEAR lt_pernr_lines.
      read_pernr_all_data(
        EXPORTING iv_pernr = lv_pernr
        IMPORTING et_lines = lt_pernr_lines
      ).
      APPEND LINES OF lt_pernr_lines TO lt_all_lines.

      IF iv_split = abap_true.
        lv_filename = |{ lv_dir }CLONE_{ lv_pernr }_{ sy-datum }.csv|.
        DATA(lv_xstr) = cl_abap_codepage=>convert_to(
          source   = concat_lines_of( table = lt_all_lines sep = cl_abap_char_utilities=>cr_lf )
          codepage = 'UTF-8' ).
        download_to_pc( EXPORTING iv_filename = lv_filename iv_data = lv_xstr IMPORTING ev_path = ev_file_path ).
        CLEAR lt_all_lines.
      ENDIF.
    ENDLOOP.

    IF iv_split = abap_false AND lt_all_lines IS NOT INITIAL.
      lv_filename = |{ lv_dir }CLONE_EXPORT_{ sy-datum }_{ sy-uzeit }.csv|.
      DATA(lv_xstring) = cl_abap_codepage=>convert_to(
        source   = concat_lines_of( table = lt_all_lines sep = cl_abap_char_utilities=>cr_lf )
        codepage = 'UTF-8' ).
      download_to_pc( EXPORTING iv_filename = lv_filename iv_data = lv_xstring IMPORTING ev_path = ev_file_path ).
    ENDIF.

    IF ev_file_path IS NOT INITIAL AND go_logger IS BOUND.
      go_logger->log_success( iv_msg = |Exportación completada: { ev_file_path }| ).
    ENDIF.
  ENDMETHOD.

  METHOD read_pernr_all_data.
    DATA: lt_infty_list TYPE STANDARD TABLE OF infty WITH DEFAULT KEY,
          lv_table      TYPE string,
          lo_data       TYPE REF TO data,
          lv_subty      TYPE string,
          lv_begda      TYPE string,
          lv_endda      TYPE string,
          lv_seqnr      TYPE string.

    CLEAR et_lines.

    " 1. Obtener lista de infotipos configurados en el sistema
    SELECT DISTINCT infty
      FROM t582a
      WHERE infty BETWEEN '0000' AND '9999'
      INTO TABLE @lt_infty_list.

    " 2. Para cada infotipo, leer registros del empleado dinámicamente
    LOOP AT lt_infty_list INTO DATA(lv_infty).
      lv_table = |PA{ lv_infty }|.

      TRY.
          CREATE DATA lo_data TYPE STANDARD TABLE OF (lv_table).
          FIELD-SYMBOLS <lt_recs> TYPE STANDARD TABLE.
          ASSIGN lo_data->* TO <lt_recs>.

          SELECT * FROM (lv_table)
            WHERE pernr = @iv_pernr
            INTO CORRESPONDING FIELDS OF TABLE @<lt_recs>.

          LOOP AT <lt_recs> ASSIGNING FIELD-SYMBOL(<ls_rec>).
            CLEAR: lv_subty, lv_begda, lv_endda, lv_seqnr.

            ASSIGN COMPONENT 'SUBTY' OF STRUCTURE <ls_rec> TO FIELD-SYMBOL(<f>).
            IF sy-subrc = 0. lv_subty = <f>. ENDIF.
            ASSIGN COMPONENT 'BEGDA' OF STRUCTURE <ls_rec> TO <f>.
            IF sy-subrc = 0. lv_begda = <f>. ENDIF.
            ASSIGN COMPONENT 'ENDDA' OF STRUCTURE <ls_rec> TO <f>.
            IF sy-subrc = 0. lv_endda = <f>. ENDIF.
            ASSIGN COMPONENT 'SEQNR' OF STRUCTURE <ls_rec> TO <f>.
            IF sy-subrc = 0. lv_seqnr = <f>. ENDIF.

            DATA(lv_xml) = serialize_record( <ls_rec> ).
            IF lv_xml IS NOT INITIAL.
              APPEND |{ gc_sect_pa }{ gc_file_sep }{ lv_infty }{ gc_file_sep }{ iv_pernr }{ gc_file_sep }{ lv_subty }{ gc_file_sep }{ lv_begda }{ gc_file_sep }{ lv_endda }{ gc_file_sep }{ lv_seqnr }{ gc_file_sep }{ lv_xml }|
                TO et_lines.
            ENDIF.
          ENDLOOP.
        CATCH cx_root.
          " Tabla no existe o error de lectura: omitir silenciosamente
      ENDTRY.
    ENDLOOP.

    " 3. TEVEN
    TRY.
        SELECT * FROM teven WHERE pernr = @iv_pernr INTO TABLE @DATA(lt_teven).
        LOOP AT lt_teven INTO DATA(ls_teven).
          DATA(lv_xml_tv) = serialize_record( ls_teven ).
          IF lv_xml_tv IS NOT INITIAL.
            APPEND |{ gc_sect_teven }{ gc_file_sep }TEVEN{ gc_file_sep }{ iv_pernr }{ gc_file_sep }{ gc_file_sep }{ ls_teven-begda }{ gc_file_sep }{ ls_teven-endda }{ gc_file_sep }{ gc_file_sep }{ lv_xml_tv }|
              TO et_lines.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.

    " 4. PTQUODED
    TRY.
        SELECT * FROM ptquoded WHERE pernr = @iv_pernr INTO TABLE @DATA(lt_ptquoded).
        LOOP AT lt_ptquoded INTO DATA(ls_ptq).
          DATA(lv_xml_pq) = serialize_record( ls_ptq ).
          IF lv_xml_pq IS NOT INITIAL.
            APPEND |{ gc_sect_ptquod }{ gc_file_sep }PTQUODED{ gc_file_sep }{ iv_pernr }{ gc_file_sep }{ gc_file_sep }{ ls_ptq-datum }{ gc_file_sep }{ gc_file_sep }{ gc_file_sep }{ lv_xml_pq }|
              TO et_lines.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.

    IF go_logger IS BOUND.
      go_logger->log_info(
        iv_pernr_src = iv_pernr
        iv_msg       = |PERNR { iv_pernr }: { lines( et_lines ) } registros exportados|
      ).
    ENDIF.
  ENDMETHOD.

  METHOD serialize_record.
    DATA: lo_writer  TYPE REF TO cl_sxml_string_writer,
          lv_xstring TYPE xstring.

    TRY.
        lo_writer = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_xml10 ).

        CALL TRANSFORMATION id
          SOURCE data = is_data
          RESULT XML lo_writer.

        lv_xstring = lo_writer->get_output( ).
        rv_xml = cl_abap_codepage=>convert_from( lv_xstring ).

        " Eliminar saltos de línea para mantener un registro por fila
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN rv_xml WITH ''.
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_xml WITH ''.
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN rv_xml WITH ''.
      CATCH cx_root.
        rv_xml = ''.
    ENDTRY.
  ENDMETHOD.

  METHOD download_to_pc.
    DATA: lt_data   TYPE STANDARD TABLE OF x255,
          lv_length TYPE i,
          lv_path   TYPE string.

    " Convertir xstring a tabla binaria
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer        = iv_data
      IMPORTING
        output_length = lv_length
      TABLES
        binary_tab    = lt_data.

    lv_path = iv_filename.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize            = lv_length
        filename                = lv_path
        filetype                = 'BIN'
      CHANGING
        data_tab                = lt_data
      EXCEPTIONS
        file_write_error        = 1
        no_batch                = 2
        gui_refuse_filetransfer = 3
        OTHERS                  = 17
    ).

    IF sy-subrc <> 0.
      " Si falla (ej: la ruta C:\temp\ no existe), descargar en el directorio temporal del GUI
      DATA: lv_temp_dir TYPE string,
            lv_name     TYPE string.

      cl_gui_frontend_services=>get_temp_directory(
        CHANGING
          temp_dir             = lv_temp_dir
        EXCEPTIONS
          OTHERS               = 5
      ).

      IF sy-subrc = 0 AND lv_temp_dir IS NOT INITIAL.
        CALL FUNCTION 'SO_SPLIT_FILE_AND_PATH'
          EXPORTING
            full_name     = lv_path
          IMPORTING
            stripped_name = lv_name.

        DATA(lv_len_temp) = strlen( lv_temp_dir ).
        IF lv_len_temp > 0.
          DATA(lv_off_temp) = lv_len_temp - 1.
          DATA(lv_last_temp) = lv_temp_dir+lv_off_temp(1).
          IF lv_last_temp <> '\' AND lv_last_temp <> '/'.
            lv_temp_dir = lv_temp_dir && `\`.
          ENDIF.
        ENDIF.

        lv_path = lv_temp_dir && lv_name.

        cl_gui_frontend_services=>gui_download(
          EXPORTING
            bin_filesize            = lv_length
            filename                = lv_path
            filetype                = 'BIN'
          CHANGING
            data_tab                = lt_data
          EXCEPTIONS
            OTHERS                  = 17
        ).
      ENDIF.
    ENDIF.

    IF sy-subrc = 0.
      ev_path = lv_path.
    ENDIF.
  ENDMETHOD.

  METHOD convert_to_json.
    DATA: lo_writer  TYPE REF TO cl_sxml_string_writer,
          lv_xstring TYPE xstring.

    TRY.
        lo_writer = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).

        CALL TRANSFORMATION id
          SOURCE data = is_data
          RESULT XML lo_writer.

        lv_xstring = lo_writer->get_output( ).
        rv_json = cl_abap_codepage=>convert_from( lv_xstring ).
      CATCH cx_root.
        rv_json = |\{"error": "Error de serialización JSON"\}|.
    ENDTRY.
  ENDMETHOD.

  METHOD get_default_path.
    cl_gui_frontend_services=>get_temp_directory(
      CHANGING
        temp_dir             = rv_path
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4
    ).

    IF sy-subrc <> 0.
      rv_path = 'C:\\TEMP\\'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
