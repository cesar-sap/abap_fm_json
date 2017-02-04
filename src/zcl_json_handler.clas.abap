class ZCL_JSON_HANDLER definition
  public
  create public .

public section.

*"* public components of class ZCL_JSON_HANDLER
*"* do not include other source files here!!!
  interfaces IF_HTTP_EXTENSION .

  type-pools ABAP .
  constants XNL type ABAP_CHAR1 value %_NEWLINE. "#EC NOTEXT
  constants XCRLF type ABAP_CR_LF value %_CR_LF. "#EC NOTEXT
  data MY_SERVICE type STRING .
  data MY_URL type STRING .

  class-methods ABAP2JSON
    importing
      !ABAP_DATA type DATA
      !NAME type STRING optional
      !UPCASE type XFELD optional
    returning
      value(JSON_STRING) type STRING
    exceptions
      ERROR_IN_DATA_DESCRIPTION .
  class-methods ABAP2PERL
    importing
      !ABAP_DATA type DATA
      !NAME type STRING optional
      !UPCASE type XFELD optional
    returning
      value(PERL_STRING) type STRING
    exceptions
      ERROR_IN_DATA_DESCRIPTION .
  class-methods ABAP2XML
    importing
      !ABAP_DATA type DATA
      !NAME type STRING optional
      !WITH_XML_HEADER type ABAP_BOOL default ABAP_FALSE
      !UPCASE type XFELD optional
      !NAME_ATR type STRING optional
    returning
      value(XML_STRING) type STRING .
  class-methods ABAP2YAML
    importing
      !ABAP_DATA type DATA
      !NAME type STRING optional
      !UPCASE type XFELD optional
      !Y_LEVEL type I default 0
      !S_INDEX type I default 0
      !FIRST_ROW type XFELD optional
      !DONT_INDENT type XFELD optional
    returning
      value(YAML_STRING) type STRING
    exceptions
      ERROR_IN_DATA_DESCRIPTION .
  class-methods BUILD_PARAMS
    importing
      !FUNCTION_NAME type RS38L_FNAM
    exporting
      !PARAMTAB type ABAP_FUNC_PARMBIND_TAB
      !EXCEPTAB type ABAP_FUNC_EXCPBIND_TAB
      !PARAMS type ANY
    exceptions
      INVALID_FUNCTION
      UNSUPPORTED_PARAM_TYPE .
  type-pools JS .
  class-methods JSON2ABAP
    importing
      !JSON_STRING type STRING optional
      !VAR_NAME type STRING optional
      !PROPERTY_PATH type STRING default 'json_obj'
    exporting
      value(PROPERTY_TABLE) type JS_PROPERTY_TAB
    changing
      !JS_OBJECT type ref to CL_JAVA_SCRIPT optional
      value(ABAP_DATA) type ANY optional
    raising
      ZCX_JSON .
  class-methods JSON_DESERIALIZE
    importing
      !JSON type STRING
    changing
      !PARAMTAB type ABAP_FUNC_PARMBIND_TAB
    raising
      ZCX_JSON .
  methods NOTES
    returning
      value(TEXT) type STRING .
  class-methods SERIALIZE_JSON
    importing
      !PARAMTAB type ABAP_FUNC_PARMBIND_TAB
      !PARAMS type ANY optional
      !EXCEPTAB type ABAP_FUNC_EXCPBIND_TAB optional
      !SHOW_IMPP type ABAP_BOOL optional
      !JSONP type STRING optional
      !LOWERCASE type ABAP_BOOL default ABAP_FALSE
    exporting
      !O_STRING type STRING .
  class-methods SERIALIZE_PERL
    importing
      !PARAMTAB type ABAP_FUNC_PARMBIND_TAB
      !PARAMS type ANY optional
      !EXCEPTAB type ABAP_FUNC_EXCPBIND_TAB optional
      !SHOW_IMPP type ABAP_BOOL optional
      !JSONP type STRING optional
      !LOWERCASE type ABAP_BOOL default ABAP_FALSE
      !FUNCNAME type RS38L_FNAM
    exporting
      !PERL_STRING type STRING .
  class-methods SERIALIZE_XML
    importing
      !PARAMTAB type ABAP_FUNC_PARMBIND_TAB
      !PARAMS type ANY optional
      !EXCEPTAB type ABAP_FUNC_EXCPBIND_TAB optional
      !SHOW_IMPP type ABAP_BOOL optional
      !JSONP type STRING optional
      !FUNCNAME type RS38L_FNAM
      !LOWERCASE type ABAP_BOOL default ABAP_FALSE
      !FORMAT type STRING optional
    exporting
      !O_STRING type STRING .
  class-methods SERIALIZE_YAML
    importing
      !PARAMTAB type ABAP_FUNC_PARMBIND_TAB
      !PARAMS type ANY optional
      !EXCEPTAB type ABAP_FUNC_EXCPBIND_TAB optional
      !SHOW_IMPP type ABAP_BOOL optional
      !JSONP type STRING optional
      !LOWERCASE type ABAP_BOOL default ABAP_FALSE
    exporting
      !YAML_STRING type STRING .
  class-methods DESERIALIZE_ID
    importing
      !JSON type STRING
    changing
      !PARAMTAB type ABAP_FUNC_PARMBIND_TAB
    raising
      ZCX_JSON .
  class-methods SERIALIZE_ID
    importing
      !PARAMTAB type ABAP_FUNC_PARMBIND_TAB
      !PARAMS type ANY optional
      !EXCEPTAB type ABAP_FUNC_EXCPBIND_TAB optional
      !SHOW_IMPP type ABAP_BOOL optional
      !JSONP type STRING optional
      !LOWERCASE type ABAP_BOOL default ABAP_FALSE
      !FORMAT type STRING default 'JSON'
      !FUNCNAME type RS38L_FNAM optional
    exporting
      !O_STRING type STRING
    raising
      ZCX_JSON .
protected section.
*"* protected components of class ZCL_JSON_HANDLER
*"* do not include other source files here!!!
private section.
*"* private components of class ZCL_JSON_HANDLER
*"* do not include other source files here!!!
ENDCLASS.



CLASS ZCL_JSON_HANDLER IMPLEMENTATION.


method ABAP2JSON.
*/**********************************************/*
*/ This method takes any ABAP data variable and /*
*/ returns a string representing its value in   /*
*/ JSON format.                                 /*
*/ ABAP references are always de-referenced and /*
*/ treated as normal variables.                 /*
*/**********************************************/*

  type-pools: abap.

  constants:
    c_comma type c value ',',
    c_colon type c value ':',
    c_quote type c value '"'.

  data:
    dont_quote type xfeld,
    json_fragments type table of string,
    rec_json_string type string,
    l_type  type c,
    s_type type c,
    l_comps type i,
    l_lines type i,
    l_index type i,
    l_value type string,
    l_name type string,
    l_strudescr type ref to cl_abap_structdescr.

  field-symbols:
    <abap_data> type any,
    <itab> type any table,
    <stru> type any table,
    <comp> type any,
    <abapcomp> type abap_compdescr.


  define get_scalar_value.
    " &1 : assigned var
    " &2 : abap data
    " &3 : abap type
    &1 = &2.
****************************************************
* Adapt some basic ABAP types (pending inclusion of all basic abap types?)
* Feel free to customize this for your needs
    case &3.
*       1. ABAP numeric types
      when 'I'. " Integer
        condense &1.
        if &1 < 0.
          shift &1 by 1 places right circular.
        endif.
        dont_quote = 'X'.

      when 'F'. " Float (pending transformation to JSON float format with no quotes)
*          condense &1.

      when 'P'. " Packed number (used in quantities, for example)
        condense &1.

      when 'X'. " Hexadecimal
*         " Leave it as is, as JSON doesn't support Hex or Octal.

*       2. ABAP char types
      when 'D'. " Date type
        CONCATENATE &1(4) '-' &1+4(2) '-' &1+6(2) INTO &1.

      when 'T'. " Time representation
        CONCATENATE &1(2) ':' &1+2(2) ':' &1+4(2) INTO &1.

      when 'N'. " Numeric text field
*           condense &1.

      when 'C' or 'g'. " Char sequences and Strings
* Put safe chars
        replace all occurrences of '\' in &1 with '\\' .
        replace all occurrences of '"' in &1 with '\"' .
        replace all occurrences of cl_abap_char_utilities=>cr_lf in &1 with '\r\n' .
        replace all occurrences of cl_abap_char_utilities=>newline in &1 with '\n' .
        replace all occurrences of cl_abap_char_utilities=>horizontal_tab in &1 with '\t' .
        replace all occurrences of cl_abap_char_utilities=>backspace in &1 with '\b' .
        replace all occurrences of cl_abap_char_utilities=>form_feed in &1 with '\f' .

      when 'y'.  " XSTRING
* Put the XSTRING in Base64
        &1 = cl_http_utility=>ENCODE_X_BASE64( &2 ).

      when others.
* Don't hesitate to add and modify scalar abap types to suit your taste.

    endcase.
** End of scalar data preparing.

* Enclose value in quotes (or not)
    if dont_quote ne 'X'.
      concatenate c_quote &1 c_quote into &1.
    endif.

    clear dont_quote.

  end-of-definition.


***************************************************
*  Prepare field names, JSON does quote names!!   *
*  You must be strict in what you produce.        *
***************************************************
  if name is not initial.
    concatenate c_quote name c_quote c_colon into rec_json_string.
    append rec_json_string to json_fragments.
    clear rec_json_string.
  endif.

**
* Get ABAP data type
  describe field abap_data type l_type components l_comps.

***************************************************
*  Get rid of data references
***************************************************
  if l_type eq cl_abap_typedescr=>typekind_dref.
    assign abap_data->* to <abap_data>.
    if sy-subrc ne 0.
      append '{}' to json_fragments.
      concatenate lines of json_fragments into json_string.
      exit.
    endif.
  else.
    assign abap_data to <abap_data>.
  endif.

* Get ABAP data type again and start
  describe field <abap_data> type l_type components l_comps.

***************************************************
*  Tables
***************************************************
  if l_type eq cl_abap_typedescr=>typekind_table.
* '[' JSON table opening bracket
    append '[' to json_fragments.
    assign <abap_data> to <itab>.
    l_lines = lines( <itab> ).
    loop at <itab> assigning <comp>.
      add 1 to l_index.
*> Recursive call for each table row:
      rec_json_string = abap2json( abap_data = <comp> upcase = upcase ).
      append rec_json_string to json_fragments.
      clear rec_json_string.
      if l_index < l_lines.
        append c_comma to json_fragments.
      endif.
    endloop.
    append ']' to json_fragments.
* ']' JSON table closing bracket


***************************************************
*  Structures
***************************************************
  else.
    if l_comps is not initial.
* '{' JSON object opening curly brace
      append '{' to json_fragments.
      l_strudescr ?= cl_abap_typedescr=>describe_by_data( <abap_data> ).
      loop at l_strudescr->components assigning <abapcomp>.
        l_index = sy-tabix .
        assign component <abapcomp>-name of structure <abap_data> to <comp>.
        l_name = <abapcomp>-name.
** ABAP names are usually in caps, set upcase to avoid the conversion to lower case.
        if upcase ne 'X'.
          translate l_name to lower case.
        endif.
        describe field <comp> type s_type.
        if s_type eq cl_abap_typedescr=>typekind_table or s_type eq cl_abap_typedescr=>typekind_dref or
           s_type eq cl_abap_typedescr=>typekind_struct1 or s_type eq cl_abap_typedescr=>typekind_struct2.
*> Recursive call for non-scalars:
          rec_json_string = abap2json( abap_data = <comp> name = l_name upcase = upcase ).
        else.
          if s_type eq cl_abap_typedescr=>TYPEKIND_OREF or s_type eq cl_abap_typedescr=>TYPEKIND_IREF.
            rec_json_string = '"REF UNSUPPORTED"'.
          else.
            get_scalar_value rec_json_string <comp> s_type.
          endif.
          concatenate c_quote l_name c_quote c_colon rec_json_string into rec_json_string.
        endif.
        append rec_json_string to json_fragments.
        clear rec_json_string. clear l_name.
        if l_index < l_comps.
          append c_comma to json_fragments.
        endif.
      endloop.
      append '}' to json_fragments.
* '}' JSON object closing curly brace


****************************************************
*                  - Scalars -                     *
****************************************************
    else.
      get_scalar_value l_value <abap_data> l_type.
      append l_value to json_fragments.

    endif.
* End of structure/scalar IF block.
***********************************

  endif.
* End of main IF block.
**********************

* Use a loop in older releases that don't support concatenate lines.
  concatenate lines of json_fragments into json_string.

endmethod.


method ABAP2PERL.
*/**********************************************/*
*/ This method takes any ABAP data variable and /*
*/ returns a string representing its value in   /*
*/ Perl Data::Dumper format, ready to be evaled /*
*/ in a Perl program.                           /*
*/**********************************************/*

  type-pools: abap.

  constants:
    c_comma type c value ',',
    c_colon type c value ':',
    c_quote type c value ''''.

  data:
    perl_hash_assign type string,
    dont_quote type xfeld,
    perl_fragments type table of string,
    rec_perl_string type string,
    l_type  type c,
    s_type  type c,
    l_comps type i,
    l_lines type i,
    l_index type i,
    l_value type string,
    l_name  type string,
    l_typedescr type ref to cl_abap_structdescr.

  field-symbols:
    <abap_data> type any,
    <itab> type any table,
    <stru> type any table,
    <comp> type any,
    <abapcomp> type abap_compdescr.

  concatenate space '=>' space into perl_hash_assign respecting blanks.

  define get_scalar_value.
    " &1 : assigned var
    " &2 : abap data
    " &3 : abap type
    &1 = &2.
****************************************************
* Adapt some basic ABAP types (pending inclusion of all basic abap types?)
* Feel free to customize this for your needs
    case &3.
*       1. ABAP numeric types
      when 'I'. " Integer
        condense &1.
        if &1 < 0.
          shift &1 by 1 places right circular.
        endif.
        dont_quote = 'X'.

      when 'F'. " Float (pending transformation to Perl float format with no quotes)
*          condense &1.

      when 'P'. " Packed number (used in quantities, for example)
        condense &1.

      when 'X'. " Hexadecimal
*         " Pending transformation to Perl hex representation.

*       2. ABAP char types
      when 'D'. " Date type
        CONCATENATE &1(4) '-' &1+4(2) '-' &1+6(2) INTO &1.

      when 'T'. " Time representation
        CONCATENATE &1(2) ':' &1+2(2) ':' &1+4(2) INTO &1.

      when 'N'. " Numeric text field
*           condense &1.

      when 'C' or 'g'. " Char sequences and Strings
* Put safe chars
        replace all occurrences of '''' in &1 with '\''' .

      when 'y'.  " XSTRING
* Put the XSTRING in Base64
        &1 = cl_http_utility=>ENCODE_X_BASE64( &2 ).

      when others.
* Don't hesitate to add and modify abap types to suit your taste.

    endcase.
** End of scalar data preparing.

* Enclose value in quotes (or not)
    if dont_quote ne 'X'.
      concatenate c_quote &1 c_quote into &1.
    endif.
    clear dont_quote.

  end-of-definition.



***************************************************
*  Prepare field names, we use single quotes.     *
*  You must be strict in what you produce.        *
***************************************************
  if name is not initial.
    concatenate c_quote name c_quote perl_hash_assign into rec_perl_string respecting blanks.
    append rec_perl_string to perl_fragments.
    clear rec_perl_string.
  endif.

**
* Get ABAP data type
  describe field abap_data type l_type components l_comps.

***************************************************
*  Get rid of data references
***************************************************
  if l_type eq cl_abap_typedescr=>typekind_dref.
    assign abap_data->* to <abap_data>.
    if sy-subrc ne 0.
      append '{}' to perl_fragments.
      concatenate lines of perl_fragments into perl_string.
      exit.
    endif.
  else.
    assign abap_data to <abap_data>.
  endif.


* Get ABAP data type again and start
  describe field <abap_data> type l_type components l_comps.

***************************************************
*  Tables
***************************************************
  if l_type eq cl_abap_typedescr=>typekind_table.
* '[' Table opening bracket
    append '[' to perl_fragments.
    assign <abap_data> to <itab>.
    l_lines = lines( <itab> ).
    loop at <itab> assigning <comp>.
      add 1 to l_index.
*> Recursive call here
      rec_perl_string = abap2perl( abap_data = <comp> upcase = upcase ).
      append rec_perl_string to perl_fragments.
      clear rec_perl_string.
      if l_index < l_lines.
        append c_comma to perl_fragments.
      endif.
    endloop.
    append ']' to perl_fragments.
* ']' Table closing bracket


***************************************************
*  Structures
***************************************************
  else .
    if l_comps is not initial.
* '{' Object opening curly brace
      append '{' to perl_fragments .
      l_typedescr ?= cl_abap_typedescr=>describe_by_data( <abap_data> ) .
      loop at l_typedescr->components assigning <abapcomp> .
        l_index = sy-tabix .
        assign component <abapcomp>-name of structure <abap_data> to <comp>.
        l_name = <abapcomp>-name.
** ABAP names are usually in caps, set upcase to avoid the conversion to lower case.
        if upcase ne 'X'.
          translate l_name to lower case.
        endif.
        describe field <comp> type s_type.
        if s_type eq cl_abap_typedescr=>typekind_table or s_type eq cl_abap_typedescr=>typekind_dref or
           s_type eq cl_abap_typedescr=>typekind_struct1 or s_type eq cl_abap_typedescr=>typekind_struct2.
*> Recursive call for non-scalars:
          rec_perl_string = abap2perl( abap_data = <comp> name = l_name upcase = upcase ).
        else.
          if s_type eq cl_abap_typedescr=>TYPEKIND_OREF or s_type eq cl_abap_typedescr=>TYPEKIND_IREF.
            rec_perl_string = '"REF UNSUPPORTED"'.
          else.
            get_scalar_value rec_perl_string <comp> s_type.
          endif.
          concatenate c_quote l_name c_quote perl_hash_assign rec_perl_string into rec_perl_string.
        endif.

        append rec_perl_string to perl_fragments.
        clear rec_perl_string.
        if l_index < l_comps.
          append c_comma to perl_fragments.
        endif.
      endloop.
      append '}' to perl_fragments.
* '}' Object closing curly brace


****************************************************
*                  - Scalars -                     *
****************************************************
    else.

      get_scalar_value l_value <abap_data> l_type.
      append l_value to perl_fragments.

    endif.
* End of structure/scalar IF block.
***********************************


  endif.
* End of main IF block.
**********************


* Use a loop in older releases that don't support concatenate lines.
  concatenate lines of perl_fragments into perl_string.

endmethod.


method ABAP2XML.
*
*/ Look at method serialize_id for a new way of doing XML.

  type-pools: abap.

  constants:
    xml_head type string value '<?xml version="1.0" encoding="utf-8"?>',
    item_atr type string value 'idx="#"'.

  data:
    xml_fragments type table of string,
    rec_xml_string type string,
    l_type  type c,
    s_type  type c,
    l_comps type i,
    l_value type string,
    t_string type string,
    l_item_atr type string,
    l_item_str type string,
    l_name type string,
    l_idx type string,
    l_typedescr type ref to cl_abap_structdescr,
    l_linedescr type ref to cl_abap_datadescr,
    l_tabledescr type ref to cl_abap_tabledescr.

  field-symbols:
    <abap_data> type any,
    <itab> type any table,
    <stru> type any table,
    <comp> type any,
    <abapcomp> type abap_compdescr.

  define get_scalar_value.
    " &1 : assigned var
    " &2 : abap data
    " &3 : abap type
    &1 = &2.
****************************************************
* Adapt some basic ABAP types (pending inclusion of all basic abap types?)
* Feel free to customize this for your needs
    case &3.
*       1. ABAP numeric types
      when 'I'. " Integer
        condense &1.
        if &1 < 0.
          shift &1 by 1 places right circular.
        endif.

      when 'F'. " Float (one day check correct XML representation)
*          condense &1.

      when 'P'. " Packed number (used in quantities, for example)
        condense &1.

      when 'X'. " Hexadecimal
*         " One day I'll check correct XML representation.

*       2. ABAP char types
      when 'D'. " Date type
        CONCATENATE &1(4) '-' &1+4(2) '-' &1+6(2) INTO &1.

      when 'T'. " Time representation
        CONCATENATE &1(2) ':' &1+2(2) ':' &1+4(2) INTO &1.

      when 'N'. " Numeric text field
*           condense &1.

      when 'C' or 'g'. " Char sequences and Strings
* Put safe chars
        t_string = &2.
        &1 = cl_http_utility=>escape_html( t_string ).

      when 'y'.  " XSTRING
* Put the XSTRING in Base64
        &1 = cl_http_utility=>ENCODE_X_BASE64( &2 ).

      when others.
* Don't hesitate to add and modify abap types to suit your taste.

    endcase.
** End of scalar data preparing.

  end-of-definition.



*******************************
* Put XML header if requested *
*******************************
  if with_xml_header eq abap_true.
    append xml_head to xml_fragments.
  endif.

***************************************************
*  Open XML tag                                   *
*  <          >                                   *
***************************************************
  if name is not initial.
    l_name = name.
    if name_atr is not initial.
      concatenate name name_atr into l_name separated by space.
    endif.
    concatenate '<' l_name '>' into rec_xml_string.
    append rec_xml_string to xml_fragments.
    clear rec_xml_string.
  endif.

**
* Get ABAP data type
  describe field abap_data type l_type components l_comps .

***************************************************
*  Get rid of data references
***************************************************
  if l_type eq cl_abap_typedescr=>typekind_dref.
    assign abap_data->* to <abap_data>.
    if sy-subrc ne 0.
      if name is not initial.
        concatenate '<' name '/>' into xml_string.
      else.
        clear xml_string.
      endif.
      exit.
    endif.
  else.
    assign abap_data to <abap_data>.
  endif.


* Get ABAP data type again and start
  describe field <abap_data> type l_type components l_comps.


***************************************************
*  Tables
***************************************************
  if l_type eq cl_abap_typedescr=>typekind_table.
    l_tabledescr ?= cl_abap_typedescr=>describe_by_data( <abap_data> ).
    l_linedescr = l_tabledescr->get_table_line_type( ).
    l_item_str = l_linedescr->get_relative_name( ).
    assign <abap_data> to <itab>.
    loop at <itab> assigning <comp>.
      l_idx = sy-tabix.
      condense l_idx.
      l_item_atr = item_atr.
      replace '#' in l_item_atr with l_idx.
      if upcase ne 'X'.
        translate l_item_str to lower case.
      endif.
*> Recursive call for line items here:
      rec_xml_string = abap2xml( abap_data = <comp> upcase = upcase name = l_item_str name_atr = l_item_atr ).
      append rec_xml_string to xml_fragments.
      clear rec_xml_string.
    endloop.


***************************************************
*  Structures
***************************************************
  else .
    if l_comps is not initial.
      l_typedescr ?= cl_abap_typedescr=>describe_by_data( <abap_data> ).
      loop at l_typedescr->components assigning <abapcomp> .
        assign component <abapcomp>-name of structure <abap_data> to <comp>.
        l_name = <abapcomp>-name. " l_value justs holds the name here.
** ABAP names are usually in caps, set upcase to avoid the conversion to lower case.
        if upcase ne 'X'.
          translate l_name to lower case.
        endif.
        describe field <comp> type s_type.
        if s_type eq cl_abap_typedescr=>typekind_table or s_type eq cl_abap_typedescr=>typekind_dref or
           s_type eq cl_abap_typedescr=>typekind_struct1 or s_type eq cl_abap_typedescr=>typekind_struct2.
*> Recursive call for non-scalars:
          rec_xml_string = abap2xml( abap_data = <comp> name = l_name upcase = upcase ).
        else.
          if s_type eq cl_abap_typedescr=>TYPEKIND_OREF or s_type eq cl_abap_typedescr=>TYPEKIND_IREF.
            rec_xml_string = 'REF UNSUPPORTED'.
          else.
            get_scalar_value rec_xml_string <comp> s_type.
          endif.
          concatenate '<' l_name '>' rec_xml_string '</' l_name '>' into rec_xml_string.
        endif.
        append rec_xml_string to xml_fragments.
        clear rec_xml_string.
      endloop.



****************************************************
*                  - Scalars -                     *
****************************************************
    else.

      get_scalar_value l_value <abap_data> l_type.
      append l_value to xml_fragments.

    endif.
* End of structure/scalar IF block.
***********************************


  endif.
* End of main IF block.
**********************


*****************
* Close XML tag *
*****************
  if name is not initial.
    concatenate '</' name '>' into rec_xml_string.
    append rec_xml_string to xml_fragments.
    clear rec_xml_string.
  endif.

* Use a loop in older releases that don't support concatenate lines.
  concatenate lines of xml_fragments into xml_string.

endmethod.


method ABAP2YAML.
*********************
* ABAP goes to YAML *
*********************

  type-pools: abap.

  constants:
    c_comma     type c value ',',
    c_space     type c value ' ',
    c_colon     type c value ':',
    c_quote     type c value '"',
    c_squot     type c value '''',
    c_colo2(2)  type c value ': ',
    c_indt2     type i value 2,
    c_hyph      type c value '-'.

  data:
  ly_level type i,
  l_dont_indent type xfeld,
  dec_level type i value 0,
  dont_quote type xfeld,
  yaml_fragments type table of string,
  rec_yaml_string type string,
  l_type  type c ,
  l_comps type i ,
  l_lines type i ,
  l_index type i ,
  l_value type string,
  l_name type string.
  field-symbols:
    <abap_data> type any,
    <itab> type any table,
    <stru> type any table,
    <comp> type any.
  data l_typedescr type ref to cl_abap_structdescr .
  field-symbols <abapcomp> type abap_compdescr .

  ly_level = y_level.

**
* Get ABAP data type
  describe field abap_data type l_type components l_comps .

***************************************************
*  First of all, get rid of data references
***************************************************
  if l_type eq cl_abap_typedescr=>typekind_dref.
    assign abap_data->* to <abap_data>.
    if sy-subrc ne 0.
      yaml_string = space. " pasamos de poner nada si falla...
      exit.
    endif.
  else.
    assign abap_data to <abap_data>.
  endif.


* Get ABAP data type again and start
  describe field <abap_data> type l_type components l_comps.

***************************************************
*  Prepare field names, YAML does not quote names *
***************************************************
* Put hyphens...
  if name is initial and y_level gt 0.
    concatenate c_hyph space into rec_yaml_string respecting blanks.
    l_dont_indent = 'X'.
  endif.

  if name is not initial.
    concatenate name c_colon c_space into rec_yaml_string respecting blanks.
  endif.

* do indent
  if dont_indent ne 'X'.
    do  ly_level  times.
      shift rec_yaml_string right by c_indt2 places.
    enddo.
  endif.

  append rec_yaml_string to yaml_fragments.
  clear rec_yaml_string.




***************************************************
*  Tables
***************************************************
  if l_type eq cl_abap_typedescr=>TYPEKIND_TABLE.
    assign <abap_data> to <itab>.
    l_lines = lines( <itab> ).
    clear l_index.
    if l_lines eq 0.
      move '[]' to rec_yaml_string.
      append rec_yaml_string to yaml_fragments.
      clear rec_yaml_string.
      append xnl to yaml_fragments.
    else.
      if name is not initial.
        append xnl to yaml_fragments.
      endif.
      add 1 to ly_level.
      loop at <itab> assigning <comp>.
        add 1 to l_index.
*> Recursive call here
        rec_yaml_string = abap2yaml( abap_data = <comp> upcase = upcase y_level = ly_level s_index = l_index ).
        append rec_yaml_string to yaml_fragments.
        clear rec_yaml_string.
      endloop.
    endif.
* YAML table ends *
*******************


***************************************************
*  Structures
***************************************************
  else .
    if l_comps is not initial.
      if name is not initial.
        append xnl to yaml_fragments.
      endif.
      add 1 to ly_level.
* Loop for structure elements
      l_typedescr ?= cl_abap_typedescr=>describe_by_data( <abap_data> ) .
      clear l_index.
      loop at l_typedescr->components assigning <abapcomp>.
        add 1 to l_index.
        assign component <abapcomp>-name of structure <abap_data> to <comp>.
        l_name = <abapcomp>-name.
** ABAP names are usually in caps, set upcase to avoid the conversion to lower case.
        if upcase ne 'X'.
          translate l_name to lower case.
        endif.
*> Recursive call here
        rec_yaml_string = abap2yaml( abap_data = <comp> name = l_name upcase = upcase y_level = ly_level s_index = l_index dont_indent = l_dont_indent ).
        clear l_dont_indent. " it is only used once
        append rec_yaml_string to yaml_fragments.
        clear rec_yaml_string.
      endloop.

* YAML structure ends *
***********************


***************************************************
*  Scalars and others...
***************************************************
    else.
      if l_type eq cl_abap_typedescr=>TYPEKIND_OREF or l_type eq cl_abap_typedescr=>TYPEKIND_IREF.
        l_value = 'REF UNSUPPORTED'.
      else.
        l_value = <abap_data>.
      endif.

* Adapt some basic ABAP types (pending inclusion of all basic abap types)
* Feel free to customize this for your needs
      case l_type.
*       1. ABAP numeric types
        when 'I'. " Integer
          condense l_value.
          if l_value < 0.
            shift l_value by 1 places right circular.
          endif.
          dont_quote = 'X'.

        when 'F'. " Float (pending transformation to JSON float format with no quotes)
*          condense l_value.

        when 'P'. " Packed number (used in quantities, for example)
          condense l_value.

        when 'X'. " Hexadecimal
*         " Leave it as is, as JSON doesn't support Hex or Octal.

*       2. ABAP char types
        when 'D'. " Date type
          CONCATENATE l_value(4) '-' l_value+4(2) '-' l_value+6(2) INTO l_value.

        when 'T'. " Time representation
          CONCATENATE l_value(2) ':' l_value+2(2) ':' l_value+4(2) INTO l_value.

        when 'N'. " Numeric text field
*           condense l_value.

        when 'C' or 'g'. " Chars and Strings
* Put safe chars
          replace all occurrences of '\' in l_value with '\\' .
          replace all occurrences of '"' in l_value with '\"' .
          replace all occurrences of cl_abap_char_utilities=>cr_lf in l_value with '\r\n' .
          replace all occurrences of cl_abap_char_utilities=>newline in l_value with '\n' .
          replace all occurrences of cl_abap_char_utilities=>horizontal_tab in l_value with '\t' .
          replace all occurrences of cl_abap_char_utilities=>backspace in l_value with '\b' .
          replace all occurrences of cl_abap_char_utilities=>form_feed in l_value with '\f' .

        when 'y'.  " XSTRING
* Put the XSTRING in Base64
*          l_value = cl_http_utility=>ENCODE_X_BASE64( <abap_data> ).
          l_value = 'XSTRING not supported in YAML yet!'.

        when others.
* Don't hesitate to add and modify abap types to suit your taste.

      endcase.

* We use YAML scalars double quoted
      if dont_quote ne 'X'.
        concatenate c_quote l_value c_quote into l_value.
      else.
        clear dont_quote.
      endif.

      append l_value to yaml_fragments.

      append xnl to yaml_fragments.

    endif. " is structure or scalar

  endif. " main typekind sentence



* Use a loop in older releases that don't support concatenate lines.
  concatenate lines of yaml_fragments into yaml_string respecting blanks.

endmethod.


method BUILD_PARAMS.

  type-pools: ABAP.

  data defval type RS38L_DEFO.
  data dataname type string.
  data waref type ref to data.

  field-symbols:
    <wa> type any,
    <temp> type any.

  data len type i.
  data excnt type i value 1.

  data paramline  type line  of ABAP_FUNC_PARMBIND_TAB.
  data exceptline type line  of ABAP_FUNC_EXCPBIND_TAB.
  data t_params_p type table of RFC_FINT_P.
  data params_p   type RFC_FINT_P.

  define remove_enclosing_quotes.
    " Remove enclosing single quotes
    if &2 gt 1.
      subtract 1 from &2.
      if &1+&2 eq ''''.
        &1+&2 = space.
      endif.
      if &1(1) eq ''''.
        shift &1 left.
      endif.
      &2 = strlen( &1 ).
    endif.
  end-of-definition.


* do we have the rfc name?
  call function 'RFC_GET_FUNCTION_INTERFACE_P'
    EXPORTING
      funcname      = function_name
      language      = 'E'       "'D'  "sy-langu
    TABLES
      params_p      = t_params_p
    EXCEPTIONS
      fu_not_found  = 1
      nametab_fault = 2
      others        = 3.

  if sy-subrc <> 0.
    raise INVALID_FUNCTION.
  endif.


* Build params table
  loop at t_params_p into params_p.

    unassign <wa>.
    unassign <temp>.
    clear paramline.

    case params_p-paramclass.

      when 'I' or 'E' or 'C'.

        paramline-name = params_p-parameter.

        if params_p-paramclass = 'E'.
          paramline-kind = ABAP_FUNC_IMPORTING.
        elseif params_p-paramclass = 'I'.
          paramline-kind = ABAP_FUNC_EXPORTING.
        else.
          paramline-kind = ABAP_FUNC_CHANGING.
        endif.

        if params_p-fieldname is initial.
          dataname = params_p-tabname.
        else.
          concatenate params_p-tabname params_p-fieldname into
              dataname separated by '-'.
        endif.

* Assign default values
        defval = params_p-default.
        if dataname is initial.
           dataname = 'STRING'.  " use a STRING for this cases (see CONVERT_DATE_TO_EXTERNAL).
        endif.
        create data waref type (dataname).
        assign waref->* to <wa>.
        len = strlen( defval ).
        remove_enclosing_quotes defval len.
        if defval = 'SPACE'.
          <wa> = space.
        elseif len > 3 and defval+0(3) = 'SY-'.
          assign (defval) to <temp>.
          <wa> = <temp>.
          unassign <temp>.
        else.
          if defval is not initial.
            <wa> = defval.
          endif.
        endif.
        unassign <wa>.
        paramline-value = waref.
        insert paramline into table paramtab.

      when 'T'.
        paramline-name = params_p-parameter.
        paramline-kind = ABAP_FUNC_TABLES.
        if params_p-exid eq 'h'.
          create data waref type (params_p-tabname).
        else.
          create data waref type standard table of (params_p-tabname).
        endif.
        paramline-value = waref.
        insert paramline into table paramtab.

      when 'X'.
        exceptline-name = params_p-parameter.
        exceptline-value = excnt.
        data messg type ref to data.
        create data messg type string.
        assign messg->* to <temp>.
        <temp> = params_p-paramtext.
        exceptline-message = messg.
        insert exceptline into table exceptab.
        add 1 to excnt.

      when others.
        raise UNSUPPORTED_PARAM_TYPE.

    endcase.

  endloop.


* add in the catch all exception
  exceptline-name = 'OTHERS'.
  exceptline-value = excnt.
  insert exceptline into table exceptab.


* return
  params = t_params_p.

*********************************
******* Remaining from 2006 *****
******* end of build_params *****
*********************************
endmethod.


method DESERIALIZE_ID.
*/***********************************************************/*
*/ New method using the built-in transformation              /*
*/ included in releases 7.02 and 7.03/7.31 (Kernelpatch 116) /*
*/***********************************************************/*

  type-pools: ABAP.

** Remember function parameter types
**constants:
**  abap_func_exporting type abap_func_parmbind-kind value 10,
**  abap_func_importing type abap_func_parmbind-kind value 20,
**  abap_func_tables    type abap_func_parmbind-kind value 30,
**  abap_func_changing  type abap_func_parmbind-kind value 40.

  data:
    rtab       type ABAP_TRANS_RESBIND_TAB,
    rlin       type abap_trans_resbind,
    oexcp      type ref to cx_root,
    etext      type string,
    json_xtext type xstring.

  field-symbols <parm> type abap_func_parmbind.

  if json is initial. exit. endif.  " exit method if there is nothing to parse

  " build rtab table for transformation id

  loop at paramtab assigning <parm>.
    if <parm>-kind eq abap_func_importing. "" va al revés, cuidado!!!
      continue.
    endif.
    rlin-name  = <parm>-name.
    rlin-value = <parm>-value.
    append rlin to rtab.
  endloop.

  " Convert input JSON variable names to uppercase

  json_xtext = cl_abap_codepage=>convert_to( json ).
  data(reader) = cl_sxml_string_reader=>create( json_xtext ).
  data(writer) = cast if_sxml_writer( cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ) ).
  do.
    data(node) = reader->read_next_node( ).
    if node is initial.
      exit.
    endif.
    if node->type = if_sxml_node=>co_nt_element_open.
      data(attributes)  = cast if_sxml_open_element( node )->get_attributes( ).
      loop at attributes assigning field-symbol(<attribute>).
        if <attribute>->qname-name = 'name'.
          <attribute>->set_value(
            to_upper( <attribute>->get_value( ) ) ).
        endif.
      endloop.
    endif.
    writer->write_node( node ).
  enddo.
  json_xtext = cast cl_sxml_string_writer( writer )->get_output( ) .

  try.

      CALL TRANSFORMATION id SOURCE XML json_xtext
                             RESULT (rtab).

    catch cx_root into oexcp.

      etext = oexcp->if_message~get_text( ).
      RAISE EXCEPTION type zcx_json
        EXPORTING
          message = etext.

  endtry.

endmethod.


method IF_HTTP_EXTENSION~HANDLE_REQUEST.
*/*************************************************************************/
*/ Assign this handler to a service in ICF. This allows any ABAP function */
*/ module to be called directly by URL and exchange data in JSON format.  */
*/ --
*/ This code is distributed under the terms of Apache License Version 2.0 */
*/ (see http://www.apache.org/licenses/LICENSE-2.0.html)                  */
*/ --
*/ (C) César Martín <cesar.martin@sap.com>                                */
*/ Many thanks to Juan Díez for his ideas, help, and support.             */
*/ --
*/*************************************************************************/
*/ If you want to use the SAP standard provided transformation for JSON   */
*/ and XML, uncomment the lines calling serialize_id and deserialize_id   */
*/*************************************************************************/
  type-pools abap.

  data: show_import_params type abap_bool value abap_false,
        lowercase type abap_bool value abap_false,
        path_info      type string,
        p_info_tab     type table of string,
        format         type string,
        accept         type string,
        action         type string,
        request_method type string,
        jsonp_callback type string,
        i_content_type type string,
        i_cdata        type string,
        o_cdata        type string,
        exceptheader   type string,
        etext          type string,
        etext2         type string,
        str_item       type string,
        host           type string,
        port           type string,
        proto          type string,
        http_code      type i,
        http_status    type string,

        funcname       type rs38l_fnam,
        funcname2      type string,
        dparam         type abap_parmname,
        t_params_p     type standard table of rfc_fint_p,
        paramtab       type abap_func_parmbind_tab,
        exceptab       type abap_func_excpbind_tab,
        exception      type line of abap_func_excpbind_tab,
        funcrc         type sy-subrc,
        oexcp          type ref to cx_root,
        qs_nvp         type tihttpnvp,
        l_lines        type i,
        l_idx          type i.

  field-symbols <qs_nvp> type ihttpnvp.
  field-symbols <fm_param> type abap_func_parmbind.
  field-symbols <fm_value_str> type string.
  field-symbols <fm_value_i> type i.
  field-symbols <fm_int_handler> type ZICF_HANDLER_DATA.

  define http_error.
    "   &1   http status code
    "   &2   status text
    "   &3   error message
    server->response->set_header_field( name = 'Content-Type'  value = 'application/json' ).
    http_code = &1.
    server->response->set_status( code = http_code  reason = &2 ).
    concatenate '{"ERROR_CODE":"' &1 '","ERROR_MESSAGE":"' &3 '","INFO_LINK":"' me->my_url me->my_service '?action=notes"}' into etext.
    server->response->set_cdata( etext ).
    exit.
  end-of-definition.

* Get Server Info:

  server->get_location( importing host = host  port = port  out_protocol = proto ).
  concatenate proto '://' host ':' port into me->my_url.

** Get all client Info:
*data clnt_hfields type TIHTTPNVP.
*server->request->get_header_fields( changing fields = clnt_hfields ).


* GET and POST and other methods are allowed.
* Uncomment or extend this if you want alternative actions following
* request methods, in order to define a REST style behaviour
* or, better, check an alternative approach on a way to do that
* inside the FM (search for _ICF_DATA below).
*  if request_method <> 'POST'.
****    http_error 405 'Method not allowed' 'Method not allowed.'.
*  endif.


* Get form and header fields
  me->my_service         = server->request->get_header_field( name = '~script_name' ).
  request_method         = server->request->get_header_field( name = '~request_method' ).
  i_content_type         = server->request->get_header_field( name = 'content-type' ).
  show_import_params   = server->request->get_form_field( 'show_import_params' ).
  action                 = server->request->get_form_field( 'action' ).
  jsonp_callback         = server->request->get_form_field( 'callback' ).
  lowercase              = server->request->get_form_field( 'lowercase' ).
  format               = server->request->get_form_field( 'format' ).
  accept               = server->request->get_header_field( name = 'Accept' ).

* Try "$" equivalents:
  if format is initial.
    format = server->request->get_form_field( '$format' ).
  endif.
  if jsonp_callback is initial.
    jsonp_callback = server->request->get_form_field( '$callback' ).
  endif.

* Get function name from PATH_INFO
  path_info = server->request->get_header_field( name = '~path_info' ).
  split path_info at '/' into table p_info_tab.
  read table p_info_tab index 2 into funcname.
  read table p_info_tab index 3 into funcname2.
  if sy-subrc eq 0.
     concatenate '//' funcname '/' funcname2 into funcname.
     condense funcname.
  endif.
  translate funcname to upper case.
  if funcname is initial and action is initial.
    http_error '404' 'Not Found' 'Empty request.' .
  endif.

***** THIS IS VERY OBSOLETE. PARAMS SHOULD NOT BE PASSED AS PATH_INFO *****
***** REMOVE THIS ******
* Read lowercase and format parameters from path_info (query string has precedence).
*  loop at p_info_tab into str_item.
*    translate str_item to lower case.
*    case str_item.
*      when 'lc'.
*        if lowercase is initial.
*          lowercase = 'X'.
*        endif.
*      when 'json' or 'yaml' or 'xml' or 'perl'.
*        if format is initial.
*          format = str_item.
*        endif.
*      when others.
*        " we'll see
*    endcase.
*  endloop.
**** REMOVE THIS *******


* Get the desired response format from "Accept" header (as in RFC 2616 sec 14.1)
* See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html. Thanks Uwe!!
  if accept is not initial and format is initial.
    translate accept to lower case.
    if accept cs '/json'.
      format = 'json'.
    elseif accept cs '/yaml'.
      format = 'yaml'.
    elseif accept cs '/xml'.
      format = 'xml'.
    elseif accept cs '/perl'.
      format = 'perl'.
    elseif accept cs '*/*'.
      clear format.  " for the moment, ignore quality levels in Accept, send default format (json).
    else.
      http_error '406' 'Not Acceptable' 'The server cannot send a response which is acceptable according to the combined Accept field value'.
    endif.
  endif.

  translate format to upper case.
  translate action to upper case.
  if show_import_params is not initial.
    show_import_params = abap_true.
  endif.


***************************
* Do alternative actions...
  case action.
    when 'NOTES'.
      server->response->set_header_field( name = 'Content-Type'  value = 'text/html' ).
      server->response->set_status( code = 200 reason = 'OK' ).
      o_cdata = me->notes( ).
      server->response->set_cdata( o_cdata ).
      exit.
*    when 'TEST'.
****** TEST *****
*      etext = me->test( i_cdata ).
*      http_error '200' 'Ok' etext.
*      exit.
****** Investigate further... *****
    when 'START_SESSION'.
**      server->stateful = 1.
      server->set_session_stateful( stateful = server->co_enabled ).
    when 'END_SESSION'.
**      server->stateful = 0.
      server->set_session_stateful( stateful = server->co_disabled ).
    when others.
      " just go on
  endcase.



* Check Authorization. Create the relevant auth object in SU21 and assign
* the authorized functions to the user. Uncomment to implement security.
  authority-check object 'Z_JSON'
         id 'FMNAME' field funcname.
  if sy-subrc ne 0.
    http_error '403' 'Not authorized' 'You are not authorized to invoke this function module.'.
  endif.



******************
* get input data *
******************
  clear i_cdata.
  i_cdata = server->request->get_cdata( ).
  server->request->get_form_fields_cs( changing fields = qs_nvp ).

* We map the query string to a simple JSON input. Handy for REST style queries.
* The query string may come from GET requests in the url and content data in
* POST request in x-www-form-urlencoded. ICF handles this perfectly and mixes both!! Great!!
  if ( qs_nvp is not initial and i_cdata is initial ) or
      i_content_type cs 'application/x-www-form-urlencoded'.
    l_lines = lines( qs_nvp ).
    clear l_idx.
    move '{' to i_cdata.
    loop at qs_nvp assigning <qs_nvp>.
      add 1 to l_idx.
      translate <qs_nvp>-name to upper case. " ABAP is upper case internally anyway.
      concatenate i_cdata '"' <qs_nvp>-name '":"' <qs_nvp>-value '"' into i_cdata
        respecting blanks.
      if l_idx < l_lines.
        concatenate i_cdata ',' into i_cdata respecting blanks.
      endif.
    endloop.
    concatenate i_cdata '}' into i_cdata.
  endif.



* Prepare params to call function
  CALL METHOD zcl_json_handler=>build_params
    EXPORTING
      function_name    = funcname
    IMPORTING
      params           = t_params_p
      paramtab         = paramtab
      exceptab         = exceptab
    EXCEPTIONS
      invalid_function = 1
      others           = 2.

  if sy-subrc <> 0.
    concatenate 'Invalid Function. ' sy-msgid sy-msgty sy-msgno ': '
            sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            into etext separated by '-'.
    http_error '500' 'Server Error' etext.
  endif.


**********************
* Process input data *
**********************
  try.
      CALL METHOD me->json_deserialize     " The classic method using JavaScript (JSON only)
*      CALL METHOD me->deserialize_id  " The new method using transformation id. This method accepts both JSON and XML input!!! Great!!
        EXPORTING
          json     = i_cdata
        CHANGING
          paramtab = paramtab.

    catch cx_root into oexcp.

      etext = oexcp->if_message~get_text( ).

      http_error '500' 'Internal Server Error' etext.

  endtry.
*/**********************************/*
*/**********************************/*



*/************************************************/*
*/ Pass some request info to function module      /*
*/ for FMs implementing a REST model or whatever  /*
*/************************************************/*
  read table paramtab with key name = '_ICF_DATA' assigning <fm_param>.
  if sy-subrc eq 0.
    create data <fm_param>-value type ZICF_HANDLER_DATA.
    assign <fm_param>-value->* to <fm_int_handler>.
    <fm_int_handler>-request_method = request_method.
    <fm_int_handler>-icf_url = me->my_url.
    <fm_int_handler>-icf_service = me->my_service.
    <fm_int_handler>-path_info = path_info.
    <fm_int_handler>-qs_tab = qs_nvp.
    <fm_int_handler>-i_json_data = i_cdata.
    append '_ICF_DATA' to <fm_int_handler>-delete_params.
    <fm_int_handler>-server = server. " Beware!
  endif.



****************************
* Call the function module *
****************************
  try.

      CALL FUNCTION funcname
        parameter-table
        paramtab
        exception-table
        exceptab.

    catch cx_root into oexcp.

      etext = oexcp->if_message~get_longtext(  preserve_newlines = abap_true ).

      http_error '500' 'Internal Server Error' etext.

  endtry.


* Remove unused exceptions
  funcrc = sy-subrc.
  delete exceptab where value ne funcrc.
  read table exceptab into exception with key value = funcrc.
  if sy-subrc eq 0.
    exceptheader = exception-name.
    CALL METHOD server->response->set_header_field(
      name = 'X-SAPRFC-Exception'
      value = exceptheader ).
  endif.


*/*******************************************************************/*
*/ Read specific FM parameters for REST type interfaces              /*
*/ I need to find a way on how to operate with some http codes:       /*
*/ 201 Created - URI of resource created is set in Location header   /*
*/ 202 Accepted - Response contains status information
*/ 203 Non-Authoritative Information
*/ 204 No Content - NO CONTENT is sent, nothing, nada
*/ 205 Reset Content - NO CONTENT is sent, nothing, nada
*/ 206 Partial Content - probably will not implement this
*/ Codes 3xx, 4xx should also be handled.
*/***********************************/*
  if <fm_int_handler> is assigned.
    if <fm_int_handler>-http_code is not initial.
      server->response->set_status( code = <fm_int_handler>-http_code  reason = <fm_int_handler>-http_status ).
      case <fm_int_handler>-http_code.
        when 204 or 205.
          exit.
        when others. " many to add?
      endcase.
    endif.
    if <fm_int_handler>-error_message is not initial.
      str_item = <fm_int_handler>-http_code. condense str_item.
      http_error str_item <fm_int_handler>-http_status <fm_int_handler>-error_message.
    endif.
* Delete indicated params for not showing them in the response
    loop at <fm_int_handler>-delete_params into dparam.
      delete paramtab where name eq dparam.
    endloop.
  endif.


* Prepare response. Serialize to output format stream.
  case format.

    when 'YAML'.

      CALL METHOD me->serialize_yaml
        EXPORTING
          paramtab    = paramtab
          exceptab    = exceptab
          params      = t_params_p
          jsonp       = jsonp_callback
          show_impp   = show_import_params
          lowercase   = lowercase
        IMPORTING
          yaml_string = o_cdata.

      server->response->set_header_field( name = 'Content-Type' value = 'text/plain' ).

    when 'PERL'.

      CALL METHOD me->serialize_perl
        EXPORTING
          paramtab    = paramtab
          exceptab    = exceptab
          params      = t_params_p
          jsonp       = jsonp_callback
          show_impp   = show_import_params
          funcname    = funcname
          lowercase   = lowercase
        IMPORTING
          perl_string = o_cdata.

      server->response->set_header_field( name = 'Content-Type' value = 'text/plain' ).

    when 'XML'.

      CALL METHOD me->serialize_xml
*      CALL METHOD me->serialize_id
        EXPORTING
          paramtab  = paramtab
          exceptab  = exceptab
          params    = t_params_p
          jsonp     = jsonp_callback
          show_impp = show_import_params
          funcname  = funcname
          lowercase = lowercase
          format    = format
        IMPORTING
          o_string  = o_cdata.

      server->response->set_header_field( name = 'Content-Type' value = 'application/xml' ).

    when others. " the others default to JSON.

      format = 'JSON'.
      CALL METHOD me->serialize_json
*      CALL METHOD me->serialize_id
        EXPORTING
          paramtab    = paramtab
          exceptab    = exceptab
          params      = t_params_p
          jsonp       = jsonp_callback
          show_impp   = show_import_params
          lowercase   = lowercase
*          format      = format
        IMPORTING
          o_string = o_cdata.

      server->response->set_header_field( name = 'Content-Type' value = 'application/json' ).
      if jsonp_callback is not initial.
        server->response->set_header_field( name = 'Content-Type' value = 'application/javascript' ).
      endif.

  endcase.


* Set response:
  server->response->set_header_field( name = 'X-Data-Format' value = format ). "
* Activate compression (will compress when size>1kb if requested by client in Accept-Encoding: gzip. Very nice.).
  server->response->set_compression( ).
  server->response->set_cdata( data = o_cdata ).

*******************************************
*******************************************
**********      *      *          *********
*********        *      *        **********
********          *      *      ***********
*******************************************
*******************************************
endmethod.


method JSON2ABAP.
*/************************************************/*
*/ Input any abap data and this method tries to   /*
*/ fill it with the data in the JSON string.      /*
*/  Thanks to Juan Diaz for helping here!!        /*
*/************************************************/*

  type-pools: abap, js.

  data:
    js_script         type string,
    js_started        type i value 0,
    l_json_string     type string,
    js_property_table type   js_property_tab,
    js_property       type line of js_property_tab,
    l_property_path   type string,
    compname          type string,
    item_path         type string.

  data:
    l_type   type c,
    l_value  type string,
    linetype type string,
    l_comp   type line of ABAP_COMPDESCR_TAB.

  data:
    datadesc type ref to CL_ABAP_TYPEDESCR,
    drefdesc type ref to CL_ABAP_TYPEDESCR,
    linedesc type ref to CL_ABAP_TYPEDESCR,
    strudesc type ref to CL_ABAP_STRUCTDESCR,
    tabldesc type ref to CL_ABAP_TABLEDESCR.

  data newline type ref to data.

  field-symbols:
    <abap_data> type any,
    <itab>      type any table,
    <comp>      type any,
    <jsprop>    type line of js_property_tab,
    <abapcomp>  type abap_compdescr.


  define assign_scalar_value.
    "   &1   <abap_data>
    "   &2   js_property-value
    describe field &1 type l_type.
    l_value = &2.
* convert or adapt scalar values to ABAP.
    case l_type.
      when 'D'. " date type
        if l_value cs '-'.
          replace all occurrences of '-' in l_value with space.
          condense l_value no-gaps.
        endif.
      when 'T'. " time type
        if l_value cs ':'.
          replace all occurrences of ':' in l_value with space.
          condense l_value no-gaps.
        endif.
      when others.
        " may be other conversions or checks could be implemented here.
    endcase.
    &1 = l_value.
  end-of-definition.


  if js_object is not bound.

    if json_string is initial. exit. endif. " exit method if there is nothing to parse

    l_json_string = json_string.
    " js_object = cl_java_script=>create( STACKSIZE = 16384 ).
    js_object = cl_java_script=>create( STACKSIZE = 16384 HEAPSIZE = 960000 ).

***************************************************
*  Parse JSON using JavaScript                    *
***************************************************
    js_object->bind( exporting name_obj = 'abap_data' name_prop = 'json_string'    changing data = l_json_string ).
    js_object->bind( exporting name_obj = 'abap_data' name_prop = 'script_started' changing data = js_started ).

* We use the JavaScript engine included in ABAP to read the JSON string.
* We simply use the recommended way to eval a JSON string as specified
* in RFC 4627 (http://www.ietf.org/rfc/rfc4627.txt).
*
* Security considerations:
*
*   Generally there are security issues with scripting languages.  JSON
*   is a subset of JavaScript, but it is a safe subset that excludes
*   assignment and invocation.
*
*   A JSON text can be safely passed into JavaScript's eval() function
*   (which compiles and executes a string) if all the characters not
*   enclosed in strings are in the set of characters that form JSON
*   tokens.  This can be quickly determined in JavaScript with two
*   regular expressions and calls to the test and replace methods.
*
*      var my_JSON_object = !(/[^,:{}\[\]0-9.\-+Eaeflnr-u \n\r\t]/.test(
*             text.replace(/"(\\.|[^"\\])*"/g, ''))) &&
*         eval('(' + text + ')');

    concatenate

         'var json_obj; '
         'var json_text; '

         'function start() { '
         '  if(abap_data.script_started) { return; } '
         '  json_text = abap_data.json_string;'
         '  json_obj = !(/[^,:{}\[\]0-9.\-+Eaeflnr-u \n\r\t]/.test( '
         '      json_text.replace(/"(\\.|[^"\\])*"/g, ''''))) && '
         '    eval(''('' + json_text + '')''); '
         '  abap_data.script_started = 1; '
         '} '

         'if(!abap_data.script_started) start(); '


       into js_script respecting blanks separated by xnl.

    js_object->compile( script_name = 'json_parser'     script = js_script ).
    js_object->execute( script_name = 'json_parser' ).

    if js_object->last_error_message is not initial.
      RAISE EXCEPTION type zcx_json
        EXPORTING
          message = js_object->last_error_message.
    endif.

  endif.
** End of JS processing.

**
  if var_name is not initial.
    concatenate property_path var_name into l_property_path separated by '.'.
  else.
    l_property_path = property_path.
  endif.
**

**
  js_property_table = js_object->get_properties_scope_global( property_path = l_property_path ).
  property_table = js_property_table.
  if l_property_path eq 'json_obj'. exit. endif.  " Just get top level properties and return

*
* Get ABAP data type, dereference if necessary and start
  datadesc = cl_abap_typedescr=>DESCRIBE_BY_DATA( abap_data ).
  if datadesc->kind eq cl_abap_typedescr=>kind_ref.
    assign abap_data->* to <abap_data>.
  else.
    assign abap_data to <abap_data>.
  endif.
  datadesc = cl_abap_typedescr=>DESCRIBE_BY_DATA( <abap_data> ).


  case datadesc->kind.

    when cl_abap_typedescr=>kind_elem.
* Scalar: process ABAP elements. Assume no type conversions for the moment.
      if var_name is initial.
        RAISE EXCEPTION type zcx_json
          EXPORTING
            message = 'VAR_NAME is required for scalar values.'.
      endif.
      js_property_table = js_object->get_properties_scope_global( property_path = property_path ).
      read table js_property_table with key name = var_name into js_property.
      if sy-subrc eq 0.
        assign_scalar_value <abap_data> js_property-value.
      endif.


    when cl_abap_typedescr=>kind_struct.
* Process ABAP structures
      strudesc ?= datadesc.
      loop at js_property_table assigning <jsprop>.
        compname = <jsprop>-name.
        translate compname to upper case.
        read table strudesc->COMPONENTS with key name = compname into l_comp.
        if sy-subrc eq 0.
          assign component l_comp-name of structure <abap_data> to <comp>.
          case l_comp-type_kind.
            when    cl_abap_typedescr=>TYPEKIND_STRUCT1  " 'v'
                 or cl_abap_typedescr=>TYPEKIND_STRUCT2  " 'u'
                 or cl_abap_typedescr=>TYPEKIND_TABLE.   " 'h' (may need a different treatment one day)
              concatenate l_property_path <jsprop>-name into item_path separated by '.'.
*> Recursive call here
              json2abap( exporting property_path = item_path changing abap_data = <comp> js_object = js_object ).

            when others.
* Process scalars in structures (same as the kind_elem above)
              assign_scalar_value <comp> <jsprop>-value.

          endcase.
        endif.
      endloop.

    when cl_abap_typedescr=>kind_table.
* Process ABAP tables
      if js_property_table is not initial.
        tabldesc ?= datadesc.
        linedesc = tabldesc->get_table_line_type( ).
        linetype = linedesc->get_relative_name( ).
        assign <abap_data> to <itab>.
        loop at js_property_table into js_property where name NE 'length'. " the JS object length
          create data newline type (linetype).
          assign newline->* to <comp>.
          case js_property-kind.
            when 'O'.
              concatenate l_property_path js_property-name into item_path separated by '.'.
              condense item_path.
*> Recursive call here
              json2abap( exporting property_path = item_path changing abap_data = newline js_object = js_object ).
            when others. " Assume scalars, 'S', 'I', or other JS types
              " Process scalars in plain table components(same as the kind_elem above)
              assign_scalar_value <comp> js_property-value.
          endcase.
          insert <comp> into table <itab>.
          free newline.
        endloop.
      endif.

    when others. " kind_class, kind_intf
      " forget it.

  endcase.


endmethod.


method JSON_DESERIALIZE.

  type-pools: ABAP, JS.

** Remember function parameter types
**constants:
**  abap_func_exporting type abap_func_parmbind-kind value 10,
**  abap_func_importing type abap_func_parmbind-kind value 20,
**  abap_func_tables    type abap_func_parmbind-kind value 30,
**  abap_func_changing  type abap_func_parmbind-kind value 40.

  data paramname   type string.
  data js_obj      type ref to cl_java_script.
  data js_prop_tab type js_property_tab.

  field-symbols <js_prop> type line of js_property_tab.
  field-symbols <parm>    type abap_func_parmbind.

  if json is initial. exit. endif.

  json2abap( exporting json_string = json  importing property_table = js_prop_tab  changing js_object = js_obj ).

  loop at js_prop_tab assigning <js_prop>.
    paramname = <js_prop>-name.
    translate paramname to upper case.
    read table paramtab with key name = paramname assigning <parm>.
    if sy-subrc eq 0.
      if <parm>-kind ne abap_func_importing. "" va al revés, cuidado!!!
        json2abap( exporting var_name = <js_prop>-name  changing abap_data = <parm>-value js_object = js_obj ).
      endif.
    endif.
  endloop.

endmethod.


method NOTES.

data location type string.

concatenate me->my_url me->my_service '/RFC_SYSTEM_INFO' into location.

concatenate

'<html><head><title>JSON (NEW) handler notes</title></head><body>'

'<h4>About this service...</h4>'
'This is the ABAP implementation of a conversion program that'
' tranforms ABAP data into a <a href="http://www.json.org">JSON</a> representation.'
'<p>'
'It provides a user interface in the form of a ICF service that '
'allows web invocation of ABAP function modules. It doesn''t matter if they are RFC enabled or not.'
'<p>In this system this service has '
'been assigned to ICF service <a href="' me->my_url me->my_service '">' me->my_service '</a>.'
'<p>'
'In order to invoke a function module, just put its name in the PATH_INFO '
'of the service URL, as is shown in the following examples.'

'<p>Try the following link to do the default call in JSON format:<pre><a href="' location '?format=json">'
location
'?format=json</a></pre>'

'<p>A simple syntax allows to get the output in different formats.<p>'

'The following gets the output in <a href="http://yaml.org">YAML</a> format:'
'<pre><a href="' location '?format=yaml">'
location
'?format=yaml</a></pre>'
''
'<p>And this will get the output in a basic XML representation: <pre><a href="' location '?format=xml">'
location
'?format=xml</a></pre>'

'<p>And, just for fun, getting it into Perl format could be handy: <pre><a href="' location '?format=perl">'
location
'?format=perl</a></pre>'

'<p>Finnally, you can add a callback to get the JSON response enclosed in a javascript function call,'
' in order to allow a <a href="http://en.wikipedia.org/wiki/JSONP">JSONP</a> style response: '
'<pre><a href="'
location '?format=json&callback=callMe">'
location '?format=json&callback=callMe</a></pre>'

'<hr><h4>WARNING</h4>This is work in progress and may not be suitable for use in productive '
'systems. The interface is somewhat unstable. Please feel free to test it and report  '
'any bug and improvement you may find.'
'<p>Use it at your own risk!'
'<p>For more information: <a href="https://cw.sdn.sap.com/cw/groups/json-adapter-for-abap-function-modules">'
'https://cw.sdn.sap.com/cw/groups/json-adapter-for-abap-function-modules</a>'
'<p>'
'If you have any questions, please contact me at <a href="mailto:cesar.martin@sap.com">'
'cesar.martin@sap.com</a>'
'<p>'


'<hr></body></html>'


into text RESPECTING BLANKS.


endmethod.


method SERIALIZE_ID.
*/***********************************************************/*
*/ New method using the built-in transformation              /*
*/ included in releases 7.02 and 7.03/7.31 (Kernelpatch 116) /*
*/ Generates both JSON and XML formats!!
*/***********************************************************/*
*/
** Remember function parameter types
**constants:
**  abap_func_exporting type abap_func_parmbind-kind value 10,
**  abap_func_importing type abap_func_parmbind-kind value 20,
**  abap_func_tables    type abap_func_parmbind-kind value 30,
**  abap_func_changing  type abap_func_parmbind-kind value 40.

  type-pools: ABAP.

  data:
    stab type ABAP_TRANS_SRCBIND_TAB,
    slin type ABAP_TRANS_SRCBIND,
    oexcp type ref to cx_root,
    etext type string,
    adata type ref to data,
    json_writer type ref to cl_sxml_string_writer.

  field-symbols <parm> type abap_func_parmbind.
*  field-symbols <excep> type abap_func_excpbind.


  loop at paramtab assigning <parm>.
    if show_impp ne 'X'
          and <parm>-kind eq abap_func_exporting. "" va al revés, cuidado!!!
      continue.
    endif.
    slin-name  = <parm>-name.
    slin-value = <parm>-value.
    append slin to stab. clear slin.
  endloop.

  if exceptab is not initial.
    slin-name  = 'EXCEPTION'.
    get reference of exceptab into adata.
    slin-value = adata.
    append slin to stab. clear slin.
  endif.


  json_writer = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).

  try.

      case format.

        when 'XML'.

          call transformation id options data_refs = 'embedded'
                                         initial_components = 'include'
                                 source (stab)
                                 result xml o_string.


        when others.

          call transformation id options data_refs = 'embedded'
                                         initial_components = 'include'
                                 source (stab)
                                 result xml json_writer.

          o_string = cl_abap_codepage=>convert_from( json_writer->get_output( ) ).
*  json_string = json_writer->get_output( ).

          if jsonp is not initial.
            concatenate jsonp '(' o_string ');' into o_string.
          endif.

      endcase.


    catch cx_root into oexcp.

      etext = oexcp->if_message~get_text( ).
      RAISE EXCEPTION type zcx_json
        EXPORTING
          message = etext.

  endtry.


endmethod.


method SERIALIZE_JSON.
* ABAP based JSON serializer for function modules (January 2013).
  type-pools: ABAP.

** Remember function parameter types
**constants:
**  abap_func_exporting type abap_func_parmbind-kind value 10,
**  abap_func_importing type abap_func_parmbind-kind value 20,
**  abap_func_tables    type abap_func_parmbind-kind value 30,
**  abap_func_changing  type abap_func_parmbind-kind value 40.

  data json_fragments type table of string.
  data rec_json_string type string.
  data paramname type string.
  data l_lines type i.
  data l_index type i.
  data upcase type xfeld value 'X'.
  field-symbols <parm> type abap_func_parmbind.
  field-symbols <excep> type abap_func_excpbind.

  if jsonp is not initial.
    append jsonp to json_fragments.
    append '(' to json_fragments.
  endif.

  rec_json_string = '{'.
  append rec_json_string to json_fragments.
  clear rec_json_string.

  clear l_index.
  l_lines = lines( paramtab ).

  loop at paramtab assigning <parm>.
    if show_impp ne 'X'
          and <parm>-kind eq abap_func_exporting. "" va al revés, cuidado!!!
      subtract 1 from l_lines.
      continue.
    endif.
    add 1 to l_index.
    paramname = <parm>-name.
    if lowercase eq abap_true.
      translate paramname to lower case.
      upcase = space.
    endif.
    rec_json_string = abap2json( abap_data = <parm>-value  name = paramname  upcase = upcase ).
    append rec_json_string to json_fragments.
    clear rec_json_string.
    if l_index < l_lines.
      append ',' to json_fragments .
    endif .
  endloop.

  if exceptab is not initial.
    if l_lines gt 0.
      append ',' to json_fragments.
    endif.
    rec_json_string = abap2json( abap_data = exceptab upcase = 'X' name = 'EXCEPTION').
    append rec_json_string to json_fragments.
    clear rec_json_string.
  endif.

  rec_json_string = '}'.
  append rec_json_string to json_fragments.
  clear rec_json_string.

  if jsonp is not initial.
    append ');' to json_fragments.
  endif.

  concatenate lines of json_fragments into o_string.

endmethod.


method SERIALIZE_PERL.
* Just for fun, generate data in Perl Data::Dumper format.

  type-pools: ABAP.

**Remember function parameter types
**constants:
**  abap_func_exporting type abap_func_parmbind-kind value 10,
**  abap_func_importing type abap_func_parmbind-kind value 20,
**  abap_func_tables    type abap_func_parmbind-kind value 30,
**  abap_func_changing  type abap_func_parmbind-kind value 40.

  data perl_fragments type table of string.
  data rec_perl_string type string.
  data paramname type string.
  data l_lines type i.
  data l_index type i.
  data upcase type xfeld value 'X'.
  data perl_var type string.
  field-symbols <parm> type abap_func_parmbind.
  field-symbols <excep> type abap_func_excpbind.

  if jsonp is not initial.
    perl_var = jsonp.
  else.
    perl_var = funcname.
  endif.
  concatenate '$' perl_var ' = {' into rec_perl_string.
  append rec_perl_string to perl_fragments.
  clear rec_perl_string.

  clear l_index.
  l_lines = lines( paramtab ).

  loop at paramtab assigning <parm>.
    if show_impp ne 'X'
          and <parm>-kind eq abap_func_exporting. "" va al revés, cuidado!!!
      subtract 1 from l_lines.
      continue.
    endif.
    add 1 to l_index.
    paramname = <parm>-name.
    if lowercase eq abap_true.
      translate paramname to lower case.
      upcase = space.
    endif.
    rec_perl_string = abap2perl( abap_data = <parm>-value  name = paramname  upcase = upcase ).
    append rec_perl_string to perl_fragments.
    clear rec_perl_string.
    if l_index < l_lines.
      append ',' to perl_fragments .
    endif .
  endloop.

  if exceptab is not initial.
    if l_lines gt 0.
      append ',' to perl_fragments.
    endif.
    rec_perl_string = abap2perl( abap_data = exceptab upcase = 'X' name = 'EXCEPTION').
    append rec_perl_string to perl_fragments.
    clear rec_perl_string.
  endif.

  rec_perl_string = '};'.
  append rec_perl_string to perl_fragments.
  clear rec_perl_string.

  concatenate lines of perl_fragments into perl_string.

endmethod.


method SERIALIZE_XML.
* Serialize function data into simple XML
*/ Look at method serialize_id for a new way of doing XML.

  type-pools: ABAP.

** Remember function parameter types
***constants:
***  abap_func_exporting type abap_func_parmbind-kind value 10,
***  abap_func_importing type abap_func_parmbind-kind value 20,
***  abap_func_tables    type abap_func_parmbind-kind value 30,
***  abap_func_changing  type abap_func_parmbind-kind value 40.

  data rec_xml_string type string.
  data xml_fragments type table of string.
  data l_funcname type string.
  data paramname type string.
  field-symbols <parm> type abap_func_parmbind.
  field-symbols <excep> type abap_func_excpbind.
    data upcase type xfeld value 'X'.

  constants:
     xml_head type string value '<?xml version="1.0" encoding="utf-8"?>'.

  append xml_head to xml_fragments.

  l_funcname = funcname.
  if lowercase eq abap_true.
     translate l_funcname to lower case.
     upcase = space.
  endif.

  concatenate '<' l_funcname '>' into rec_xml_string.
  append rec_xml_string to xml_fragments.

  loop at paramtab assigning <parm>.
    if show_impp ne 'X'
          and <parm>-kind eq abap_func_exporting. "" va al revés, cuidado!!!
      continue.
    endif.
    paramname = <parm>-name.
    if lowercase eq abap_true.
       translate paramname to lower case.
    endif.
    rec_xml_string = abap2xml( name = paramname abap_data = <parm>-value upcase = upcase ).
    append rec_xml_string to xml_fragments.
  endloop.

  if exceptab is not initial.
    rec_xml_string = abap2xml( name = 'EXCEPTION' abap_data = exceptab  upcase = upcase ).
    append rec_xml_string to xml_fragments.
  endif.

  concatenate '</' l_funcname '>' into rec_xml_string.
  append rec_xml_string to xml_fragments.

  concatenate lines of xml_fragments into o_string.

endmethod.


method SERIALIZE_YAML.
* Now, go and represent function data in YAML (http://yaml.org)

  type-pools: ABAP.
** Remember function parameter types
**constants:
**  abap_func_exporting type abap_func_parmbind-kind value 10,
**  abap_func_importing type abap_func_parmbind-kind value 20,
**  abap_func_tables    type abap_func_parmbind-kind value 30,
**  abap_func_changing  type abap_func_parmbind-kind value 40.

  data yaml_fragments type table of string.
  data rec_yaml_string type string.
  data rec_yaml_table type table of string.
  data paramname type string.
  field-symbols <parm> type abap_func_parmbind.
  field-symbols <excep> type abap_func_excpbind.
  data upcase type xfeld value 'X'.
  data yaml_head type string value '--- #YAML:1.0'.

  concatenate yaml_head xnl into rec_yaml_string.
  append rec_yaml_string to yaml_fragments.
  clear rec_yaml_string.

  loop at paramtab assigning <parm>.
    if show_impp ne 'X'
          and <parm>-kind eq abap_func_exporting. "" va al revés, cuidado!!!
      continue.
    endif.
    paramname = <parm>-name.
    if lowercase eq abap_true.
       translate paramname to lower case.
       upcase = space.
    endif.
    rec_yaml_string = abap2yaml( abap_data = <parm>-value  name = paramname upcase = upcase ).
    append rec_yaml_string to yaml_fragments.
    clear rec_yaml_string.
  endloop.

  if exceptab is not initial.
    rec_yaml_string = abap2yaml( abap_data = exceptab name = 'EXCEPTION' upcase = 'X' ).
    append rec_yaml_string to yaml_fragments.
    clear rec_yaml_string.
  endif.

*  append xnl to yaml_fragments.

  concatenate lines of yaml_fragments into yaml_string.

*  if jsonp is not initial.
*     concatenate jsonp '(' yaml_string ');' into yaml_string.
*  endif.

endmethod.
ENDCLASS.
