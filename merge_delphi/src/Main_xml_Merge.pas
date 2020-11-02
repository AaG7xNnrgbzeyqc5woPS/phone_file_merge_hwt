unit Main_xml_Merge;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus, StdCtrls, ExtCtrls, ComCtrls, public_type, Log;

type
  TForm_xml_zip = class(TForm)
    mm1: TMainMenu;
    About1: TMenuItem;
    Merge1: TMenuItem;
    LoadXML1: TMenuItem;
    btn_open_xml: TButton;
    lbl_xml: TLabel;
    dlgOpen1: TOpenDialog;
    edt_xml_configue: TEdit;
    lbl1: TLabel;
    edt_outputfile: TEdit;
    btn_open_output: TButton;
    btn_merge_begin: TButton;
    pb_FileProcess: TProgressBar;
    pb_dataProcess: TProgressBar;
    lbl_patch: TLabel;
    edt_Patch: TEdit;
    btn_Open_patch: TButton;
    edt_sectors: TEdit;
    Sectors: TLabel;
    rg_imgformat: TRadioGroup;
    btn_log: TButton;
    procedure btn_open_outputClick(Sender: TObject);
    procedure btn_open_xmlClick(Sender: TObject);
    procedure btn_merge_beginClick(Sender: TObject);
    procedure btn_Open_patchClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btn_logClick(Sender: TObject);
  private
    { Private declarations }
//    procedure Merge(inputxml: string; outputbin: string; DiskSizeInBytes: Int64);
  

    procedure update_fileProcessbar(count, total : int64);
    procedure update_dataProcessbar(count, total : int64);
    procedure Do_MergeComplete(Sender: TObject);
    
  public
    { Public declarations }
//    procedure DoMerge;
  end;

var
  Form_xml_zip: TForm_xml_zip;

implementation

uses
  Unit_FileCheck, Unit_xml, unit_DoMergeThread, Unit_Patch;

{$R *.dfm}

procedure TForm_xml_zip.btn_open_outputClick(Sender: TObject);
begin
  dlgOpen1.Filter := '';
  if  dlgOpen1.Execute then
  begin
    //out_fs := dlgOpen1.FileName;
    edt_outputfile.Text := dlgOpen1.FileName
  end;
end;

procedure TForm_xml_zip.btn_open_xmlClick(Sender: TObject);
begin
  dlgOpen1.Filter := '*.xml|*.xml';
  if  dlgOpen1.Execute then
  begin
    edt_xml_configue.Text := dlgOpen1.FileName;
  end;

end;

procedure TForm_xml_zip.update_fileProcessbar(count, total : int64);
begin
    pb_FileProcess.Position := Round((count / total) * 100);
    //application.ProcessMessages; //这个好用，效果不错
    // application.HandleMessage不好用，会等待消息，很慢的

end;

procedure TForm_xml_zip.update_dataProcessbar(count, total : int64);
begin
  pb_dataProcess.Position := Round((count / total) * 100);
  //application.ProcessMessages;

end;

procedure TForm_xml_zip.Do_MergeComplete(Sender: TObject);
begin
  //ShowMessage('文件合并完成！');
  ShowMessage('Merge Completed！');
end;


procedure TForm_xml_zip.btn_merge_beginClick(Sender: TObject);
var
  Evn: TEvnUserParam;
begin

  //Inttostr();
{  if rg_chip.ItemIndex >= 0 then
  begin
    DiskSizeInBytes := 4 * int64(1024*1024*1024); //4G
    DiskSizeInBytes := DiskSizeInBytes shl rg_chip.ItemIndex;
  end
  else raise Exception.Create('请选择芯片容量');
 }
  MLog.reset_device_log;

  with Evn do
  begin
    EXEName := Application.ExeName;
    BytesPerSector    := 512;
    ChipSizeInSectors := StrToIntdef(Trim(edt_sectors.Text),-1);
    ChipSizeInBytes   := ChipSizeInSectors * BytesPerSector;
  end;

  if  (Length(edt_xml_configue.Text) > 0) and  (Length(edt_outputfile.Text) > 0)
    and (Evn.ChipSizeInBytes > 0) then
  begin
    with Evn do
    begin
      patchxml  := trim(edt_Patch.Text);
      inputxml  := trim(edt_xml_configue.Text);
      outputbin := trim(edt_outputfile.Text);
      WorkPath  := ExtractFileDir(inputxml);
      SetCurrentDirectory(PChar(WorkPath));     //GetCurrentDirectory //Application.ExeName
    end;

    MLog.PrintEvnUserParam(Evn);
    //-----------------------------------------------

    ExecuteInThread(nil,Evn,  update_dataProcessbar, update_fileProcessbar, Do_MergeComplete);
  end
  else
  begin
    MLog.PrintBigError('请选择输入输出文件,输入芯片容量扇区数！');
    //raise Exception.Create('请选择输入输出文件,输入芯片容量扇区数！');
  end;

end;

procedure TForm_xml_zip.btn_Open_patchClick(Sender: TObject);
begin
  dlgOpen1.Filter := '*.xml|*.xml';
  if  dlgOpen1.Execute then
  begin
    edt_Patch.Text := dlgOpen1.FileName;
  end;


end;

procedure TForm_xml_zip.FormCreate(Sender: TObject);
begin
  Caption := 'EMMC Merge utility Ver 2.05  2016-5-20';
  MLog := TMergeLog.Create();
  //MLog.isPrintXML := True;
end;

procedure TForm_xml_zip.btn_logClick(Sender: TObject);
begin
  with MLog do
  begin
    reset_device_log();
    device_log('MergeUtility is running!');
    device_log('-----------');
    PrintBigWarning('PrintBigWarning Test!');
    PrintBigError('PrintBigError Test');
  end;
end;

end.
