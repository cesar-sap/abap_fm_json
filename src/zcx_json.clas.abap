class ZCX_JSON definition
  public
  inheriting from CX_STATIC_CHECK
  final
  create public .

public section.

  constants ZCX_JSON type SOTR_CONC value '000C293CED061EE2A2D7BA5F40F0C8DE'. "#EC NOTEXT
  data MESSAGE type STRING value 'undefined'. "#EC NOTEXT .  .  . " .

  methods CONSTRUCTOR
    importing
      !TEXTID like TEXTID optional
      !PREVIOUS like PREVIOUS optional
      !MESSAGE type STRING default 'undefined' .
protected section.
private section.
ENDCLASS.



CLASS ZCX_JSON IMPLEMENTATION.


method CONSTRUCTOR ##ADT_SUPPRESS_GENERATION.
CALL METHOD SUPER->CONSTRUCTOR
EXPORTING
TEXTID = TEXTID
PREVIOUS = PREVIOUS
.
 IF textid IS INITIAL.
   me->textid = ZCX_JSON .
 ENDIF.
me->MESSAGE = MESSAGE .
endmethod.
ENDCLASS.
