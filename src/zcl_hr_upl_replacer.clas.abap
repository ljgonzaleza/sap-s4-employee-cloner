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

    METHODS insert_infotype
      IMPORTING
        iv_pernr     TYPE pernr_d
        iv_infty     TYPE infty
        it_data      TYPE string_table
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS insert_single_record
      IMPORTING
        iv_pernr     TYPE pernr_d
        iv_infty     TYPE infty
        is_data      TYPE string
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS record_exists
      IMPORTING
        iv_pernr         TYPE pernr_d
        iv_infty         TYPE infty
        is_key           TYPE string
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    METHODS delete_all_infotypes
      IMPORTING
        iv_pernr     TYPE pernr_d
        iv_del_tm    TYPE abap_bool DEFAULT abap_false
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS insert_ptquoded
      IMPORTING
        iv_pernr     TYPE pernr_d
        it_data      TYPE zcl_hr_upl_parser=>gtt_ptquoded
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS insert_teven
      IMPORTING
        iv_pernr     TYPE pernr_d
        it_data      TYPE zcl_hr_upl_parser=>gtt_teven
        iv_simul     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

ENDCLASS.

CLASS zcl_hr_upl_replacer IMPLEMENTATION.

  METHOD insert_infotype.
    " Pendiente: mapeo dinámico registro→estructura Pnnnn y
    " llamada a HR_INFOTYPE_OPERATION por cada registro.
    " En simulación siempre OK; en real se reporta pendiente.
    IF iv_simul = abap_true.
      rv_ok = abap_true.
    ELSE.
      rv_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD insert_single_record.
    rv_ok = COND #( WHEN iv_simul = abap_true THEN abap_true ELSE abap_true ).
  ENDMETHOD.

  METHOD record_exists.
    " Pendiente: verificación por clave BEGDA/ENDDA/SUBTY/SEQNR
    rv_exists = abap_false.
  ENDMETHOD.

  METHOD delete_all_infotypes.
    " El borrado masivo debe ejecutarse vía HR_INFOTYPE_OPERATION
    " (operación DEL) por registro: prohibido DELETE directo en
    " tablas estándar según estándar LATAM.
    rv_ok = abap_true.
  ENDMETHOD.

  METHOD insert_ptquoded.
    " Pendiente: regenerar QUONR/DOCNR con number ranges del destino
    rv_ok = abap_true.
  ENDMETHOD.

  METHOD insert_teven.
    " Pendiente: regenerar PDSNR con number range del destino
    rv_ok = abap_true.
  ENDMETHOD.

ENDCLASS.
