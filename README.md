JSON Adapter for ABAP Function Modules
======================================

Welcome to the JSON adapter for ABAP Function Modules!! (or adaptor)

This adapter was first published in SAP SCN blog (http://scn.sap.com/community/abap/connectivity/blog/2013/03/05/json-adapter-for-abap-function-modules). The blog remains its main reference and discussion place.

This adapter is specific to SAP ABAP systems. It should work on any SAP release from 7.0 onwards, however some slight modifications may be needed for older SP levels. 

The purpose of this adaptor is to allow calling ABAP function modules via HTTP and serializing the input and output in JSON format. This allows a very simple way to invoke ABAP functionality from HTML5 and AJAX or Jquery based applications. 

## How to install

In order to install this you need [SAPLink](https://sap.assembla.com/spaces/saplink/wiki). First install SAPLink in your ABAP server following the [SAPLink installation instrucctions](http://wiki.scn.sap.com/wiki/display/ABAP/SAPlink+User+Documentation). Be sure to install the required [SAPLink plugins](https://www.assembla.com/spaces/saplink/wiki/SAPlink_plugin_list). To minimize trouble, I recommend your installing the [Nugget that contains all commonly used plugings](https://www.assembla.com/spaces/saplink-plugins/subversion/source/HEAD/build).

This adaptor works with any ABAP version from 7.0 onwards. I have tested it in 7.31 and 7.40, which are the two releases where I can currently maintain it. If you are using any older release please contact me for indications.

As a rule, to make it work in any pre 7.31 release, you have to comment out all calls to the ABAP built-in JSON converter, that is, the calls to the methods SERIALIZE_ID and DESERIALIZE_ID in HANDLE_REQUEST and the code inside both methods. You cannot use them anyway in pre 7.31 releases. 


### ABAP Authorization 

The module includes an AUTHORITY_CHECK call to a custom authorization object named Z_JSON that validates if the user can access the function module. 

You must create and authorization object with the name Z_JSON and just one field named FNMANE as authorization objects are not yet transported with SAPLink. Use transaction SU21 for this.

The authorization object will be included in the corresponding user profile. An asterisk (*) will allow the user to access all function modules. It is very recommended that any user that is going to access function modules through this adaptor has a profile with just the functions that he is allowed to access.


## How to invoke

### Create ICF service

You must create a service in ICF to make an endpoint for the adaptor. Here goes an example in transaction SICF:

![Define ICF service for the JSON adaptor](https://raw.githubusercontent.com/cesar-sap/abap_fm_json/master/SICF.jpg)

In this example, you will invoke the service using the following syntax:

`http(s)://your_abap_server:<port>/fmcall/<function_module_name>?<parameters>`

### Function module parameters

You can pass as GET query string parameters any of the function IMPORT parameters that are defined and single data types (not structures or tables).

In order to pass structures or tables to the function module, use any of the HTTP methods that support a content body (POST or PUT mainly).

Some parameters exist as standard. Most notably:

`format=<output_format` set the format of the response,
`lowercase=X` will show ABAP variable names in lower case,
`show_import_params=X` will include the IMPORT parameters in the response,
`callback=<callback_name>` wraps response in a JavaScript callback function. 

### Supported output formats

The adaptor can produce output in the following formats:

JSON:

XML:

YAML:

PERL: just for fun. 

## Session and logon support

## Cross Site requests

## Notes

### ABAP based or transformation based serializers

## Contact


