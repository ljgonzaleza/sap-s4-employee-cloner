*&============================================================*
*& Class ZCL_HR_UPL_LOGGER
*&============================================================*
*& Descripción: Logger del programa de upload de empleados     *
*& Fecha Creación = 10.06.2026                              *
*& Creador      = LATAM Development Team                    *
*& Empresa      = LATAM                                     *
*&============================================================*
*& Histórico de modificaciones                              *
*&============================================================*
*& Marca  Fecha       Autor  Descripción                      *
*& @001   2026.06.10  —     Versión inicial                  *
*&============================================================*

CLASS zcl_hr_upl_logger DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS start_session.
    METHODS end_session.

    METHODS log_error
      IMPORTING
        iv_msg TYPE string.

    METHODS log_success
      IMPORTING
        iv_msg TYPE string.

  PROTECTED SECTION.

    DATA: go_logger TYPE REF TO zcl_hr_cln_logger.

ENDCLASS.

CLASS zcl_hr_upl_logger IMPLEMENTATION.

  METHOD start_session.
    go_logger = NEW zcl_hr_cln_logger( ).
    go_logger->start_session( ).
  ENDMETHOD.

  METHOD end_session.
    IF go_logger IS BOUND.
      go_logger->end_session( ).
    ENDIF.
  ENDMETHOD.

  METHOD log_error.
    IF go_logger IS BOUND.
      go_logger->log_error( iv_msg = iv_msg ).
    ENDIF.
  ENDMETHOD.

  METHOD log_success.
    IF go_logger IS BOUND.
      go_logger->log_success( iv_msg = iv_msg ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
