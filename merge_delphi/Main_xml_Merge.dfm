object Form_xml_zip: TForm_xml_zip
  Left = 622
  Top = 166
  Width = 593
  Height = 377
  Caption = #22823#23481#37327#21512#24182' 2016.5.6'
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
    Top = 192
    Width = 75
    Height = 25
    Caption = 'Execute'
    TabOrder = 4
    OnClick = btn_merge_beginClick
  end
  object rg_chip: TRadioGroup
    Left = 224
    Top = 176
    Width = 137
    Height = 65
    Caption = 'ChipSize'
    Columns = 2
    Items.Strings = (
      '4G'
      '8G'
      '16G'
      '32G'
      '64G'
      '128G')
    TabOrder = 5
  end
  object pb_FileProcess: TProgressBar
    Left = 56
    Top = 272
    Width = 401
    Height = 17
    TabOrder = 6
  end
  object pb_dataProcess: TProgressBar
    Left = 56
    Top = 248
    Width = 401
    Height = 17
    TabOrder = 7
  end
  object edt_Patch: TEdit
    Left = 216
    Top = 56
    Width = 169
    Height = 21
    TabOrder = 8
  end
  object btn_Open_patch: TButton
    Left = 408
    Top = 56
    Width = 75
    Height = 25
    Caption = 'Open'
    TabOrder = 9
    OnClick = btn_Open_patchClick
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
