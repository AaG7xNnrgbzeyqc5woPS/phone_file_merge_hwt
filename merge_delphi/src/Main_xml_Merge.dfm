object Form_xml_zip: TForm_xml_zip
  Left = 649
  Top = 330
  Width = 593
  Height = 377
  Caption = 'Merger 2016.5.23'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = mm1
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object lbl_xml: TLabel
    Left = 120
    Top = 24
    Width = 84
    Height = 13
    Caption = 'XML Configue File'
  end
  object lbl1: TLabel
    Left = 152
    Top = 96
    Width = 53
    Height = 13
    Caption = 'OutPut File'
  end
  object lbl_patch: TLabel
    Left = 152
    Top = 64
    Width = 46
    Height = 13
    Caption = 'Patch File'
  end
  object Sectors: TLabel
    Left = 144
    Top = 128
    Width = 60
    Height = 13
    Caption = 'Sectors Num'
  end
  object edt_xml_configue: TEdit
    Left = 216
    Top = 24
    Width = 169
    Height = 21
    ReadOnly = True
    TabOrder = 0
  end
  object btn_open_xml: TButton
    Left = 408
    Top = 24
    Width = 75
    Height = 25
    Caption = 'Open'
    TabOrder = 1
    OnClick = btn_open_xmlClick
  end
  object edt_outputfile: TEdit
    Left = 216
    Top = 88
    Width = 169
    Height = 21
    ReadOnly = True
    TabOrder = 2
    Text = 'd:\singleimage.bin'
  end
  object btn_open_output: TButton
    Left = 408
    Top = 88
    Width = 75
    Height = 25
    Caption = 'open'
    TabOrder = 3
    OnClick = btn_open_outputClick
  end
  object btn_merge_begin: TButton
    Left = 408
    Top = 168
    Width = 75
    Height = 25
    Caption = 'Execute'
    TabOrder = 4
    OnClick = btn_merge_beginClick
  end
  object pb_FileProcess: TProgressBar
    Left = 56
    Top = 272
    Width = 401
    Height = 17
    TabOrder = 5
  end
  object pb_dataProcess: TProgressBar
    Left = 56
    Top = 248
    Width = 401
    Height = 17
    TabOrder = 6
  end
  object edt_Patch: TEdit
    Left = 216
    Top = 56
    Width = 169
    Height = 21
    TabOrder = 7
  end
  object btn_Open_patch: TButton
    Left = 408
    Top = 56
    Width = 75
    Height = 25
    Caption = 'Open'
    TabOrder = 8
    OnClick = btn_Open_patchClick
  end
  object edt_sectors: TEdit
    Left = 216
    Top = 120
    Width = 169
    Height = 21
    TabOrder = 9
    Text = '7634944'
  end
  object rg_imgformat: TRadioGroup
    Left = 152
    Top = 160
    Width = 233
    Height = 41
    Columns = 2
    ItemIndex = 1
    Items.Strings = (
      'zip format'
      'image format')
    TabOrder = 10
  end
  object btn_log: TButton
    Left = 24
    Top = 192
    Width = 75
    Height = 25
    Caption = 'log'
    TabOrder = 11
    Visible = False
    OnClick = btn_logClick
  end
  object mm1: TMainMenu
    Left = 24
    object Merge1: TMenuItem
      Caption = 'Merge'
      object LoadXML1: TMenuItem
        Caption = 'LoadXML'
      end
    end
    object About1: TMenuItem
      Caption = 'About'
    end
  end
  object dlgOpen1: TOpenDialog
    Left = 40
    Top = 104
  end
end
