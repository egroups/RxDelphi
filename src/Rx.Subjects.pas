(*
  Implementation of typical Observable.

  Before deciding to implement your own Observable,
  check here.

  --- Implicit infrastructure ---

  There are principles that may not be obvious in the code.
  One of the most important is that no event will be issued
  after the sequence is complete (onError or onCompleted).
  The implementation of the subject 'respects these principles.

  Security can not be guaranteed wherever Rx is used,
  so you better be aware and not violate this principle,
  as this can lead to vague consequences.
*)
unit Rx.Subjects;

interface
uses Rx, Rx.Implementations, Generics.Collections;

type

  ///	<summary>
  /// The simplest implementation of Subject. When data is transmitted to
  /// PublishSubject, it issues them to all subscribers who are subscribed to
  /// him at the moment.
  ///	</summary>
  TPublishSubject<T> = class(TObservableImpl<T>)
  public
    procedure OnNext(const Data: T); override;
  end;

  ///	<summary>
  /// Has a special ability to cache all the incoming data.
  /// When he has a new subscriber, the sequence is given to him
  /// since the beginning. All subsequent received data will be provided
  /// subscribers as usual.
  ///	</summary>
  TReplaySubject<T> = class(TPublishSubject<T>)
  type
    TValue = TSmartVariable<T>;
    TVaueDescr = record
      Value: TValue;
      Stamp: TTime;
    end;
  strict private
    FCache: TList<TVaueDescr>;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    constructor Create;

    ///	<summary>
    ///	  <para>
    ///     Caching everything is not always the best idea, because
     ///    sequences can be long or even infinite.
    ///	  </para>
    ///	  <para>
    ///     CreateWithSize limits the size of the buffer, and
     ///    CreateWithTime time that objects will remain in the cache.
    ///	  </para>
    ///	</summary>
    constructor CreateWithSize(Size: LongWord);
    constructor CreateWithTime(Time: LongWord;
      TimeUnit: LongWord = Rx.TimeUnit.MILLISECONDS; From: TDateTime=Rx.StdSchedulers.IMMEDIATE);
    destructor Destroy; override;
    procedure OnNext(const Data: T); override;
  end;


  ///	<summary>
  ///  BehaviorSubject stores only the last value. This is the same as
  ///  and ReplaySubject, but with a buffer of size 1. During creation, it can
  ///  to be assigned an initial value, thus ensuring that the data
  ///  will always be available to new subscribers.
  ///	</summary>
  TBehaviorSubject<T> = class(TPublishSubject<T>)
  strict private
    FValue: TSmartVariable<T>;
    FValueExists: Boolean;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    constructor Create(const Value: T); overload;
    procedure OnNext(const Data: T); override;
  end;


  ///	<summary>
  /// Also stores the last value. The difference is that it does not issue data
  /// until the sequence ends. It is used when
  /// you need to give a single value and immediately end.
  ///	</summary>
  TAsyncSubject<T> = class(TObservableImpl<T>)
  type
    TValue = TSmartVariable<T>;
  strict private
    FCache: TList<TValue>;
  protected
    property Cache: TList<TValue> read FCache;
  public
    constructor Create;
    destructor Destroy; override;
    procedure OnNext(const Data: T); override;
    procedure OnCompleted; override;
  end;

implementation
uses SysUtils, Rx.Schedulers;

{ TPublishSubject<T> }

procedure TPublishSubject<T>.OnNext(const Data: T);
var
  Contract: IContract;
  Ref: TSmartVariable<T>;
begin
  inherited;
  Ref := Data;
  if Supports(Scheduler, StdSchedulers.ICurrentThreadScheduler) then
    for Contract in Freeze do
      Contract.GetSubscriber.OnNext(TSmartVariable<T>.Create(Data))
  else
    for Contract in Freeze do
      Scheduler.Invoke(TOnNextAction<T>.Create(Data, Contract))
end;

{ TReplaySubject<T> }

constructor TReplaySubject<T>.Create;
begin
  FCache := TList<TVaueDescr>.Create;
end;

constructor TReplaySubject<T>.CreateWithSize(Size: LongWord);
begin
  Create;
end;

constructor TReplaySubject<T>.CreateWithTime(Time: LongWord; TimeUnit: LongWord;
  From: TDateTime);
begin
  Create;
end;

destructor TReplaySubject<T>.Destroy;
begin
  FCache.Free;
  inherited;
end;

procedure TReplaySubject<T>.OnNext(const Data: T);
var
  Descr: TVaueDescr;
begin
  inherited OnNext(Data);
  Descr.Value := Data;
  Descr.Stamp := Now;
  FCache.Add(Descr);
end;

procedure TReplaySubject<T>.OnSubscribe(Subscriber: ISubscriber<T>);
var
  Descr: TVaueDescr;
begin
  inherited;
  for Descr in FCache do
    Subscriber.OnNext(Descr.Value);
end;

{ TBehaviorSubject<T> }

constructor TBehaviorSubject<T>.Create(const Value: T);
begin
  inherited Create;
  FValue := Value;
  FValueExists := True;
end;

procedure TBehaviorSubject<T>.OnNext(const Data: T);
begin
  inherited;
  FValue := Data;
  FValueExists := True;
end;

procedure TBehaviorSubject<T>.OnSubscribe(Subscriber: ISubscriber<T>);
begin
  inherited;
  if FValueExists then
    Subscriber.OnNext(FValue);
end;

{ TAsyncSubject<T> }

constructor TAsyncSubject<T>.Create;
begin
  inherited Create;
  FCache := TList<TValue>.Create;
end;

destructor TAsyncSubject<T>.Destroy;
begin
  FCache.Free;
  inherited;
end;

procedure TAsyncSubject<T>.OnCompleted;
var
  Value: TValue;
  Contract: IContract;
begin
  if Supports(Scheduler, StdSchedulers.ICurrentThreadScheduler) then
    for Contract in Freeze do
      for Value in FCache do
        Contract.GetSubscriber.OnNext(Value)
  else
    for Contract in Freeze do
      for Value in FCache do
        Scheduler.Invoke(TOnNextAction<T>.Create(Value, Contract));
  inherited;
end;

procedure TAsyncSubject<T>.OnNext(const Data: T);
begin
  inherited;
  FCache.Add(Data);
end;

end.
