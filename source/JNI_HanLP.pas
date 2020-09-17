unit JNI_HanLP;

{
  JNI_HanLP
  ===============================================================
  Call HanLP using JNI.pas.

  Written by caowm (remobjects@qq.com)
  16 September 2020

  Reference
  ===============================================================
  HanLP: Han Language Processing
  https://github.com/hankcs/HanLP/tree/1.x

  DelphiJNI: A Delphi/Kylix Java Native Interface implementation
  https://github.com/aleroot/DelphiJNI
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.Variants,
  JNI,
  JNIUtils,
  JNI_Tool;

type

  // ƴ������ɲ���=��ĸ+��ĸ+����12345
  TPinyin = class
  public
    Shengmu: string;
    Yunmu: string;
    Tone: integer;
    Head: string;
    FirstChar: Variant;
    Pinyin: string;
    PinyinWithToneMark: string;
    PinyinWithoutTone: string;
  end;

  // һ�����ʣ��û�����ֱ�ӷ��ʴ˵��ʵ�ȫ������
  TTerm = class
  public
    Word: string;
    Nature: string;
    Offset: integer;
    function ToString(): string; override;
  end;

  // �ִ������ִʷ���
  TSegment = class
  private
    FJVM: TJNIEnv;
    FSegment: JObject;
  public
    constructor Create(JVM: TJNIEnv; ASegment: JObject);

    function SegmentClassName(): string;

    // �ִ�
    function Seg(const Text: string): TObjectList<TTerm>;

    // �ִʶϾ� ���������ʽ
    function Seg2sentence(const Text: string): TObjectList<TObjectList<TTerm>>;
  end;

  // �����Դ���������ýӿڹ�����
  THanLP = class
  private
    FJVM: TJNIEnv;
    FHanLPClass: JClass;
  public
    constructor Create(JVM: TJNIEnv);

    // ת��Ϊƴ��
    function ConvertToPinyinString(const Text, Separator: string;
      RemainNone: boolean): string;

    // ת��Ϊƴ��������ĸ��
    function ConvertToPinyinFirstCharString(const Text, Separator: string;
      RemainNone: boolean): string;

    // ת��Ϊƴ��
    function ConvertToPinyinList(const Text: string): TObjectList<TPinyin>;

    // ��ת��
    function ConvertToSimplifiedChinese(const TraditionalChineseString
      : string): string;

    // ��ת��
    function ConvertToTraditionalChinese(const SimplifiedChineseString
      : string): string;

    // ��ȡ�ؼ���
    function ExtractKeyword(const Document: string; Size: integer)
      : TArray<string>;

    // ��ȡ�ؼ���
    function ExtractPhrase(const Text: string; Size: integer): TArray<string>;

    // �Զ�ժҪ �ָ�Ŀ���ĵ�ʱ��Ĭ�Ͼ��ӷָ��Ϊ��,��:��������?��!��;
    function ExtractSummary(const Document: string; Size: integer)
      : TArray<string>;

    // �Զ�ժҪ �ָ�Ŀ���ĵ�ʱ��Ĭ�Ͼ��ӷָ��Ϊ��,��:��������?��!��;
    function GetSummary(const Document: string; MaxLength: integer): string;

    // �ִ�
    function Segment(const Text: string): TObjectList<TTerm>;

    // ����һ���ִ��� ����һ����������
    function NewSegment(): TSegment; overload;

    {
      ����һ���ִ���

      algorithm - �ִ��㷨�������㷨����Ӣ���������ԣ���ѡ�б�
      ά�ر� (viterbi)��Ч�ʺ�Ч�������ƽ��
      ˫����trie�� (dat)�����ٴʵ�ִʣ�ǧ���ַ�ÿ��
      ��������� (crf)���ִʡ����Ա�ע������ʵ��ʶ�𾫶ȶ��ϸߣ��ʺ�Ҫ��ϸߵ�NLP����
      ��֪�� (perceptron)���ִʡ����Ա�ע������ʵ��ʶ��֧������ѧϰ
      N���· (nshort)������ʵ��ʶ����΢��һЩ���������ٶ�
    }
    function NewSegment(const Algorithm: string): TSegment; overload;

  end;

  // Pinyin to TPinyin
function ConvertPinyin(JVM: TJNIEnv; Obj: JObject): TPinyin;

// Term to TTerm
function ConvertTerm(JVM: TJNIEnv; Obj: JObject): TTerm;

implementation

function ConvertPinyin(JVM: TJNIEnv; Obj: JObject): TPinyin;
begin
  Result := TPinyin.Create;

  Result.Pinyin := CallMethod(JVM, Obj, 'toString', 'String()', []);
  Result.PinyinWithToneMark := CallMethod(JVM, Obj, 'getPinyinWithToneMark',
    'String()', []);
  Result.PinyinWithoutTone := CallMethod(JVM, Obj, 'getPinyinWithoutTone',
    'String()', []);
  Result.Head := CallMethod(JVM, Obj, 'getHeadString', 'String()', []);
  Result.Shengmu := Result.Head;
  Result.FirstChar := CallMethod(JVM, Obj, 'getFirstChar', 'char()', []);
  Result.Tone := CallMethod(JVM, Obj, 'getTone', 'int()', []);
  // Yunmu��Java�Ǹ�enum������ת����string
  Result.Yunmu := JObjectToString(JVM, CallObjectMethod(JVM, Obj, 'getYunmu',
    'com.hankcs.hanlp.dictionary.py.Yunmu()', []));
end;

function ConvertTerm(JVM: TJNIEnv; Obj: JObject): TTerm;
begin
  Result := TTerm.Create;
  Result.Word := GetFieldValue(JVM, Obj, 'word', 'String');
  Result.Offset := GetFieldValue(JVM, Obj, 'offset', 'int');
  Result.Nature := JObjectToString(JVM, GetObjectFieldValue(JVM, Obj, 'nature',
    'com.hankcs.hanlp.corpus.tag.Nature'));
end;

{ TTerm }

function TTerm.ToString: string;
begin
  Result := Word + '/' + Nature;
end;

{ TSegment }

constructor TSegment.Create(JVM: TJNIEnv; ASegment: JObject);
begin
  FJVM := JVM;
  FSegment := ASegment;
end;

function TSegment.SegmentClassName: string;
begin
  Result := GetClassName(FJVM, FSegment);
end;

function TSegment.Seg(const Text: string): TObjectList<TTerm>;
var
  List: JObject;
begin
  List := CallObjectMethod(FJVM, FSegment, 'seg',
    'java.util.List(String)', [Text]);
  Result := TObjectList<TTerm>(ConvertObjectList(FJVM, List, @ConvertTerm));
end;

function TSegment.Seg2sentence(const Text: string)
  : TObjectList<TObjectList<TTerm>>;
begin
  // todo:
end;

{ THanLP }

function THanLP.ConvertToPinyinFirstCharString(const Text, Separator: string;
  RemainNone: boolean): string;
begin
  Result := CallMethod(FJVM, FHanLPClass, 'convertToPinyinFirstCharString',
    'String(String,String,boolean)', [Text, Separator, RemainNone], True);
end;

function THanLP.ConvertToPinyinList(const Text: string): TObjectList<TPinyin>;
var
  List: JObject;
begin
  List := CallObjectMethod(FJVM, FHanLPClass, 'convertToPinyinList',
    'java.util.List(String)', [Text], True);
  Result := TObjectList<TPinyin>(ConvertObjectList(FJVM, List, @ConvertPinyin));
end;

function THanLP.ConvertToPinyinString(const Text, Separator: string;
  RemainNone: boolean): string;
begin
  Result := CallMethod(FJVM, FHanLPClass, 'convertToPinyinString',
    'String(String,String,boolean)', [Text, Separator, RemainNone], True);
end;

function THanLP.ConvertToSimplifiedChinese(const TraditionalChineseString
  : string): string;
begin
  Result := CallMethod(FJVM, FHanLPClass, 'convertToSimplifiedChinese',
    'String(String)', [TraditionalChineseString], True);
end;

function THanLP.ConvertToTraditionalChinese(const SimplifiedChineseString
  : string): string;
begin
  Result := CallMethod(FJVM, FHanLPClass, 'convertToTraditionalChinese',
    'String(String)', [SimplifiedChineseString], True);
end;

constructor THanLP.Create(JVM: TJNIEnv);
begin
  FJVM := JVM;
  FHanLPClass := FJVM.FindClass('com/hankcs/hanlp/HanLP');
end;

function THanLP.ExtractKeyword(const Document: string; Size: integer)
  : TArray<string>;
var
  List: JObject;
begin
  List := CallObjectMethod(FJVM, FHanLPClass, 'extractKeyword',
    'java.util.List(String,int)', [Document, Size], True);
  Result := ConvertStringList(FJVM, List);
end;

function THanLP.ExtractPhrase(const Text: string; Size: integer)
  : TArray<string>;
var
  List: JObject;
begin
  List := CallObjectMethod(FJVM, FHanLPClass, 'extractPhrase',
    'java.util.List(String,int)', [Text, Size], True);
  Result := ConvertStringList(FJVM, List);
end;

function THanLP.ExtractSummary(const Document: string; Size: integer)
  : TArray<string>;
var
  List: JObject;
begin
  List := CallObjectMethod(FJVM, FHanLPClass, 'extractSummary',
    'java.util.List(String,int)', [Document, Size], True);
  Result := ConvertStringList(FJVM, List);
end;

function THanLP.GetSummary(const Document: string; MaxLength: integer): string;
begin
  Result := CallMethod(FJVM, FHanLPClass, 'getSummary', 'String(String,int)',
    [Document, MaxLength], True);
end;

function THanLP.NewSegment(const Algorithm: string): TSegment;
begin
  Result := TSegment.Create(FJVM, CallObjectMethod(FJVM, FHanLPClass,
    'newSegment', 'com.hankcs.hanlp.seg.Segment(String)', [Algorithm], True));
end;

function THanLP.NewSegment: TSegment;
begin
  Result := TSegment.Create(FJVM, CallObjectMethod(FJVM, FHanLPClass,
    'newSegment', 'com.hankcs.hanlp.seg.Segment()', [], True));
end;

function THanLP.Segment(const Text: string): TObjectList<TTerm>;
var
  List: JObject;
begin
  List := CallObjectMethod(FJVM, FHanLPClass, 'segment',
    'java.util.List(String)', [Text], True);
  Result := TObjectList<TTerm>(ConvertObjectList(FJVM, List, @ConvertTerm));
end;

end.
