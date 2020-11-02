program MergeUtility;

uses
  Forms,
  Merge in 'Merge.pas' {Form_Main},
  Unit_FileCheck in 'Unit_FileCheck.pas',
  xmltest in 'xmltest.pas' {Form_xml_test},
  Unit_xml in 'Unit_xml.pas',
  Main_xml_Merge in 'Main_xml_Merge.pas' {Form_xml_zip},
  unit_DoMergeThread in 'unit_DoMergeThread.pas',
  Unit_Patch in 'Unit_Patch.pas',
  CRC32_file in 'CRC32_file.pas',
  Log in 'Log.pas',
  public_type in 'public_type.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm_xml_zip, Form_xml_zip);
  Application.CreateForm(TForm_xml_test, Form_xml_test);
  Application.CreateForm(TForm_Main, Form_Main);
  Application.Run;
end.
