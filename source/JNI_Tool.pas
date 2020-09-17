unit JNI_Tool;

{
  JNI_Tool
  ===============================================================
  Tools to help use JNI and HanLP.

  Written by caowm (remobjects@qq.com)
  16 September 2020
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  JNI,
  JNIUtils;

type
  // convert JObject to TObject
  TConvertJObject = function(JVM: TJNIEnv; Obj: JObject): TObject;

  {
    ����JVM����

    ************************ע������*****************************

    1. ���ú�JREĿ¼��jvm.dllҪ������·���У���������޷�����

    2. ����Ŀ��ƽ̨Ҫ��jvm��ͬ��32λjvm��32λ����64λjvm��64λ����

    3. �õ���jar��Ҫָ��jar�����ƣ����磺-Djava.class.path=./hanlp-1.7.8.jar

    4. Debugģʽ�¼���jvm��access violation������ʱż��Ҳ����just ignore it.
    �ο� https://stackoverflow.com/questions/36250235/exception-0xc0000005-from-jni-createjavavm-jvm-dll

  }
function Create_JVM(const Version: Integer;
  const Options: array of Ansistring): TJNIEnv;

// ת��Java List<Object>��Delphi TObjectList<TObject>
function ConvertObjectList(JVM: TJNIEnv; List: JObject;
  Converter: TConvertJObject): TObjectList<TObject>;

// ת��Java List<String>��Delphi TArray<string>
function ConvertStringList(JVM: TJNIEnv; List: JObject): TArray<string>;

// ����Java Object.toString()����
function JObjectToString(JVM: TJNIEnv; Obj: JObject): string;

// ��ȡ����
function GetClassName(JVM: TJNIEnv; Obj: JObject): string;

implementation

resourcestring
  JVMCreateFails = 'JVM creation fails, return code is %d.';

function Create_JVM(const Version: Integer;
  const Options: array of Ansistring): TJNIEnv;
var
  PJvm: PJavaVM;
  PEnv: PJNIEnv;
  VMArgs: JavaVMInitArgs;
  VMOptions: array of JavaVMOption;
  I: Integer;
begin
  SetLength(VMOptions, Length(Options));
  for I := 0 to High(VMOptions) do
  begin
    VMOptions[I].optionString := PAnsiChar(Options[I]);
  end;

  VMArgs.Version := Version;
  VMArgs.nOptions := Length(Options);
  VMArgs.ignoreUnrecognized := false;
  VMArgs.Options := @VMOptions[0];
  I := JNI_CreateJavaVM(@PJvm, @PEnv, @VMArgs);
  if I <> 0 then
    raise EJNIError.Create(Format(JVMCreateFails, [I]));

  Result := TJNIEnv.Create(PEnv);
end;

// ת��Java List<Object>��Delphi TObjectList<TObject>
function ConvertObjectList(JVM: TJNIEnv; List: JObject;
  Converter: TConvertJObject): TObjectList<TObject>;
var
  Count: Integer;
  I: Integer;
  Obj: JObject;
begin
  Result := TObjectList<TObject>.Create(True);
  Count := CallMethod(JVM, List, 'size', 'int()', []);
  for I := 0 to Count - 1 do
  begin
    Obj := CallObjectMethod(JVM, List, 'get', 'java/lang/Object(int)', [I]);
    Result.Add(Converter(JVM, Obj));
  end;
end;

// ת��Java List<String>��Delphi TArray<string>
function ConvertStringList(JVM: TJNIEnv; List: JObject): TArray<string>;
var
  Count: Integer;
  I: Integer;
  Obj: JObject;
begin
  Count := CallMethod(JVM, List, 'size', 'int()', []);
  if (Count = 0) then
    Exit();
  SetLength(Result, Count);
  for I := 0 to Count - 1 do
  begin
    Obj := CallObjectMethod(JVM, List, 'get', 'java/lang/Object(int)', [I]);
    Result[I] := JVM.JStringToString(Obj);
  end;
end;

function JObjectToString(JVM: TJNIEnv; Obj: JObject): string;
begin
  if Obj = nil then
    Result := ''
  else
    Result := CallMethod(JVM, Obj, 'toString', 'String()', []);
end;

// ��ȡ����
function GetClassName(JVM: TJNIEnv; Obj: JObject): string;
var
  Cls: JObject;
begin
  if Obj = nil then
    Result := ''
  else
  begin
    Cls := CallObjectMethod(JVM, Obj, 'getClass', 'java.lang.Class()', []);
    Result := CallMethod(JVM, Cls, 'getName', 'String()', []);
  end;
end;

end.
