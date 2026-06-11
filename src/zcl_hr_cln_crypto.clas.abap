*&============================================================*
*& Class ZCL_HR_CLN_CRYPTO
*&============================================================*
*& Descripción: Utilidad de cifrado/descifrado para archivos  *
*& exportados por ZHR_CLONE_OUT2 e importados por ZHR_CLONE_IN2*
*& Algoritmo: XOR con clave compartida (simétrico)            *
*& Formato en archivo: cabecera + datos en hexadecimal        *
*& Fecha Creación = 11.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.11  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_cln_crypto DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    " Cabecera que identifica un archivo cifrado
    CONSTANTS gc_enc_marker TYPE string VALUE '#ENC:LATAM_HR_CLN_V1'.

    " Clave compartida (misma en clone_out y clone_in — transportar juntos)
    CONSTANTS gc_key         TYPE string VALUE 'L@T4M_HR_CL0N3_K3Y_2026!'.

    " Cifrado/descifrado XOR (operación simétrica: crypt == decrypt)
    CLASS-METHODS crypt
      IMPORTING iv_data        TYPE xstring
                iv_key         TYPE string DEFAULT gc_key
      RETURNING VALUE(rv_result) TYPE xstring.

    " Cifra iv_data y devuelve el contenido listo para escribir en archivo
    " (cabecera + hex del resultado cifrado, codificado en UTF-8)
    CLASS-METHODS encrypt_for_file
      IMPORTING iv_data          TYPE xstring
      RETURNING VALUE(rv_content) TYPE xstring.

    " Lee el contenido binario de un archivo; si está cifrado lo descifra
    " y devuelve el xstring original (texto plano pipe-delimitado)
    CLASS-METHODS decrypt_from_file
      IMPORTING iv_content       TYPE xstring
      RETURNING VALUE(rv_data)   TYPE xstring.

ENDCLASS.

CLASS zcl_hr_cln_crypto IMPLEMENTATION.

  METHOD crypt.
    " XOR byte a byte con clave rotante.
    " Para archivos de datos HR (típicamente < 5 MB) el rendimiento es aceptable.
    DATA: lv_xkey   TYPE xstring,
          lv_result TYPE xstring,
          lv_len    TYPE i,
          lv_klen   TYPE i,
          lv_off    TYPE i,
          lv_kidx   TYPE i,
          lv_x1     TYPE x LENGTH 1,
          lv_k1     TYPE x LENGTH 1,
          lv_enc1   TYPE x LENGTH 1.

    IF iv_data IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        lv_xkey = cl_abap_codepage=>convert_to( source = iv_key codepage = 'UTF-8' ).
      CATCH cx_root.
        rv_result = iv_data.
        RETURN.
    ENDTRY.

    lv_len  = xstrlen( iv_data ).
    lv_klen = xstrlen( lv_xkey ).

    IF lv_klen = 0.
      rv_result = iv_data.
      RETURN.
    ENDIF.

    " Cifrado XOR byte a byte
    DO lv_len TIMES.
      lv_off  = sy-index - 1.
      lv_kidx = lv_off MOD lv_klen.
      lv_x1   = iv_data+lv_off(1).
      lv_k1   = lv_xkey+lv_kidx(1).
      lv_enc1 = lv_x1 BIT-XOR lv_k1.
      " Concatenar byte cifrado al resultado
      CONCATENATE lv_result lv_enc1 INTO lv_result IN BYTE MODE.
    ENDDO.

    rv_result = lv_result.
  ENDMETHOD.

  METHOD encrypt_for_file.
    DATA: lv_encrypted TYPE xstring,
          lv_hex       TYPE string,
          lv_content   TYPE string.

    lv_encrypted = crypt( iv_data ).
    " El template sobre xstring genera su representación hexadecimal
    lv_hex = |{ lv_encrypted }|.
    lv_content = |{ gc_enc_marker }{ cl_abap_char_utilities=>cr_lf }{ lv_hex }|.

    TRY.
        rv_content = cl_abap_codepage=>convert_to( source = lv_content codepage = 'UTF-8' ).
      CATCH cx_root.
        rv_content = iv_data.
    ENDTRY.
  ENDMETHOD.

  METHOD decrypt_from_file.
    DATA: lv_text  TYPE string,
          lt_lines TYPE string_table,
          lv_first TYPE string,
          lv_hex   TYPE string.

    TRY.
        lv_text = cl_abap_codepage=>convert_from( source = iv_content codepage = 'UTF-8' ).
      CATCH cx_root.
        rv_data = iv_content.
        RETURN.
    ENDTRY.

    SPLIT lv_text AT cl_abap_char_utilities=>cr_lf INTO TABLE lt_lines.
    IF lt_lines IS INITIAL.
      SPLIT lv_text AT cl_abap_char_utilities=>newline INTO TABLE lt_lines.
    ENDIF.

    READ TABLE lt_lines INTO lv_first INDEX 1.
    IF sy-subrc <> 0 OR lv_first <> gc_enc_marker.
      " Archivo sin cabecera de cifrado — devolver tal cual
      rv_data = iv_content.
      RETURN.
    ENDIF.

    READ TABLE lt_lines INTO lv_hex INDEX 2.
    IF sy-subrc <> 0 OR lv_hex IS INITIAL.
      rv_data = iv_content.
      RETURN.
    ENDIF.

    TRY.
        " Hex string → xstring → descifrar XOR → datos originales
        rv_data = crypt( CONV xstring( lv_hex ) ).
      CATCH cx_root.
        rv_data = iv_content.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
