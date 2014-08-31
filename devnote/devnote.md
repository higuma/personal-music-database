# 開発メモ(保存用)

(2014-07-18..28)

まず今回のお題をまとめる。

* 元は少し前に作ったもの
    * <https://github.com/higuma/music-database-webapp>
    * サーバサイドAPIはRuby on Railsで作った
        * RESTful APIを作るのならやっぱりRailsが一番!
    * Railsを使えば作るのは楽だが気楽にはデモ公開できない
        * もしやるとしたらちゃんと認証機能なども作らないとだめ
* 今回はこれをlocalStorageで作る(これなら気楽に公開できる)
* ビルドツールはgulpを使う(gruntよりよさそう)

最初はgulpのお勉強。Sassのモジュールは2種類ある。

* gulp-sass
    * 純正Ruby版SassでなくC++版Sass(SassC)を使う(採用しない)
* gulp-ruby-sass
    * 純正Ruby版Sassのインターフェース(これを使う)
        * ただし生成ファイルのpermissionが意味不明(なぜ-xを付ける?)
        * でもこの症状は無害なのでしばらくこれを使うことにする

watchが簡単にできるのがポイント(gulp-watchを使うだけ)。次はその簡単な例。

<http://qiita.com/yuku_t/items/dce7214f153173493315>

Gulpはまあ何とかなるが、それよりBackbone.localStorageを何とかせねば。最初からコードを読むよりlocalStorageの内容をconsole出力すると内部メカニズムが分かる。

基本的にはid-valueだが、今回は3階層ある。Railsの場合はActive Record associationを使えば簡単にできるが、今回はlocalStorageなのでクライアント側にコードを追加しないと解決できない。

具体的に今足りないのはRailsではサーバサイドが行っている上位IDの設定。

* Artistはそのまま
* ReleaseにはartistIdを追加
* TrackにはreleaseIdを追加

> (後で補足)今回は下位項目から上位を参照することはなく、さらにlocalStorageのキーに子孫項目情報を含める仕様を採用したため、最終的にはこれらの親項目IDが不要になった。しかし後でどう仕様変更するか分からないので残しておく。

またurlは全く用いないのでcollectionのurlは削除してよい。

Railsを使った場合はサーバ側ロジックはサーバで組めばいいが、今回は全てクライアントサイドで行う必要がある。

* modal new/editのapplyで
    * create - createの前に必要
    * update - saveの前は不要(createですでに設定されている)

またdeleteもdependenciesの部分は自分で処理しないとだめ。

* trackはその下がないので問題なし
* releaseはそれをownerとするtrack全て自分でdelete
* artistはそれをownerとするreleaseを全てdelete
   * それに伴いreleaseをownerとするtrackも全てdelete

------------------------------------------------------------------------

やはりBackbone.LocalStorageをちゃんと読んでおかないと対応できそうにない。まず機能を把握する。元のBackbone.syncの仕様は次の通り。

* Backbone.sync(method, model, [options])
    * method: 'create', 'read', 'update', 'patch', 'delete'のひとつ
    * model: saveするmodelまたはcollection
    * option: たくさんある(ここは略)
    * 戻り値: jQuery.ajaxの戻り値(Deferredオブジェクト)

Backbone.localStorageはこの仕様をsimulateしている。コードの解析は後ろから順にトップダウンで読むと分かりやすい。

* Backbone.sync(method, model, options)をoverride
    * methodは'create', 'read'等
    * modelはModelまたはCollectionのインスタンス
        * model_or_collectionとした方が丁寧だがちょっと長すぎるので...
    * optionsはこれからチェックする(hash)

* Backbone.getSyncMethod(model) - まずlocalStorageを使うかどうかを確認
    * 次のどちらかの場合はlocalSyncを使う
        * model(実際はcollectionの方が多いはず).localStorageが存在
        * model.collection.localStororageが存在
    * 典型的にはCollectionにlocalStorageを設定すればよい

* その結果により処理が異なる
    * 存在すればBackbone.localSyncを使う($.ajaxをsimulate)
    * なければBackbone.ajaxSync(元のBackbone.sync)を使う
    * これにより部分的にlocalStorageを使うことが可能になる

* Backbone.localSync(method, model, options) を呼び出す
    * model(collection)からstoreを取得
        * modelやcollectionの中に生成したBackbone.LocalStorageオブジェクト
    * まず戻り値として$.Deferred()を準備(本物を使用)
        * なければBackbone.Deferred()を試す(しかし今のBackboneにはない)
    * 実際の処理はstoreに任せる
        * switch (method) {...}の中(ここはそのまま読めばOK)
    * 後半は戻り値の処理なので後で読む(今はskip)

* Backbone.LocalStorageが本体

* new Backbone.LocalStorage(name, serializer)
    * @nameはlocalStorageのキー文字列
    * @serializerの仕様は次の通り(通常は指定不要)
        * .serialize - デフォルトはJSON.stringify
        * .deserialize - デフォルトはJSON.parse
    * @recordsは現在のlocalStorageの値
        * 初期値は[]
        * getItemしてカンマでsplit
            * ということは値が','を含んではいけないことになる?(以下注意)

インスタンスメソッド(prototype)は次の通り。

* .save() - @records初期化の逆
    * @recordsを','でjoinしてsetItem

* .create(model)
    * model.id = GUIDをセット
    * .idAttributeをセット

まあこれくらいにしておこう。感じは分かった。最大のポイントはLocalStorage(name, ...)のnameで、これがキーになる。ただしBackbone.LocalStorageはネストするリソースは想定していないので自分で対応する必要がある。

まずnameは自分で設定する。各collectionに対して設定すべき値は次の通り。

* artistはこのままでOK
* releaseは"release-#{artist\_id}"
* trackも同様に"track-#{track\_id}"

これでdelete以外はうまくいくはず...と思ったがだめ。

* 作成や変更はできるし、切り替えも作用はする
* しかしページをリロードすると全てが台無しになる

コードを読んでいたらBackbone.LocalStorageはそもそもこういう事を考慮した作りではない事が分かった。ポイントはthis.recordsで、この一変数に注目してコードを解読すると理由が分かる。

Collectionの初期化(一覧読み出し)を行う場所は実は一箇所しかない。それがBackbone.LocalStorageのコンストラクタで、ここの最後でgetItem(@name)してsplitし@recordsに保存している。

その後は@recordsを全面書き換えする箇所はない。findAllも現在の@recordsのIDを使って要素を読み込んでいるに過ぎない。

> 一般的なRESTful API仕様に準拠していないと思う(やはりfindAllではlocalStorageにアクセスして該当する一覧全てを取得すべき)。しかし作者はそもそもリソースの入れ子を想定していないのでこれは仕方ない。

今回は深いことは考えず、releaseとtrackについては毎回fetchする直前にlocalStorageを作り直すことにする(ctorでしか一覧を取得しないため、ソースに手を加えずに対応するにはこれしか方法がない)。

> ただしこれでBackbone.LocalStorageが複雑な構造のリソースに対応していないことも分かってしまった(自分で作らないとだめ)。今後もし本格的に作ることがあれば全部自分で作り直すことを検討すべき。

------------------------------------------------------------------------

もうひとつ違いを見つけた。syncは後でcallbackせず直接コールスタックの奥深くで呼び出される。つまり遅延評価ではなく(昔のWindowsメッセージみたいな)深々とした関数呼び出しになる。

今までのコードには遅延評価を前提としている部分があるので修正する必要がある。アイテムを選択した場合のコールスタックを辿ってみる(手順前後が発生するのはどうやらここ一箇所だけ)。

* (parent).onSelectItem
    * (parent).syncChildView
        * (child).syncFromParent
            * @items.setOwner(owner)
                * (items).fetch()   deferredの場合はここでスタックが戻るが...
                    * .sync()       このように内側でコールされる
                        * ...以下同様

修正前の状態(前後問題の把握)と修正後を示す。

```
artistView.select
    .render
    .syncChildView
        releaseView.syncFromParent
            @items.setOwner @item
                # @item = nullはこの場所に移動する
                releaseItems.fetch() - sync発生
                    releaseView.onSync ...見つけた!
            ここで成功したら@item = nullしているが
                * サーバアクセスがあればここでスタックが戻る
                * しかしコールした奥でsyncを発生している 
```

> $.Deferredを適切に使えば同じ順序にできるはず。しかしここは極力シンプルに実装しようという作者の意図かも知れない(これはこれで分からなくもない)。

------------------------------------------------------------------------

残りはdeleteだけ。もしサーバサイドで処理できればサーバに任せた方がよい(Ruby on Rails版参照)。しかし今回は全部クライアント側で処理する必要がある。でも遅延評価が必要ないのだから処理はむしろ簡単になると思った方がいい。

* 親itemをdelete
    * まずconfirm
    * Yesならrecursiveに深さ優先で次を実行
        * 葉の末端までscan
            * 末端に達したらdelete
        * 末端を全てdeleteして空になった親をdelete
        * 以下繰り返し

実はこういう事をしなくても表面上はできるのだが、根本だけ削除するとその先の枝全体がlocalStorageの中にゴミとして永久に残る。

> 開発中はコンソールから`localStorage.clear()`(別名「バルス」?)とタイプすれば消せる。

------------------------------------------------------------------------

Rubyのような本当のオブジェクト志向言語であればmodelのdeleteをoverrideすれば済む話だが、Backbone(Underscore)のextendは単に属性を書き換えるだけで元のメソッドに上書きされてしまう。

> 実はBackboneのextendの代わりにCoffeeScriptのclassとsuperを使えばできるのだが、今回はすでに半完成状態のコードがあるのでより簡単に対応する。

この部分はCommandsというモジュールを作って対応した(動作もOK)。

------------------------------------------------------------------------

後は細かい部分を詰める。

グローバル(Navbar)メニューとして次の2点を追加する。

* Fill sample data (populate)
* Clear data (clear)

これらの実装はそんなに難しくない(完了)。しかし処理時間が思いの他長い。今回100k強(約170アルバム分)のデモデータを作った(分量としてこれくらいが妥当)。しかしこれだとpopulate/clearどちらも5秒近く要する。

> これはどうもBackbone(.localStorage)の処理時間の遅さに起因しているのでは...ただし今回はまだ我慢できる程度なのでこれ以上深入りしない。

> > というのは誤りで(すぐ後で気付いた)、本当の原因は要素を操作する度にいちいちonSyncが発生して無駄なrenderを繰り返しているため。ここは後で直す。

この状況だと最低限の対応としてカーソルをwaitにするくらいはやっておいた方がよさそうだ。実際に次の2点で対応した。

* bodyに対してカーソルをwaitに設定
* Bootstrap.buttonの機能を使い、処理中はApplyボタンをProcessing...に変更
* 処理終了後に上記2点を解除

しかしこれは正しく実装してもほとんど機能しない。

* Chrome(実際はChromium)上で
    * populateした時にApplyボタンを"Processing..."にする機能だけOK
    * cursor:waitは
        * devtools - Elementsでinsepctすると正しく設定されている
        * だが画面に反映されない
        * でも時々waitカーソルが表示されることがある
        * 特殊ケースで機能する(頻度が増す)事も確認している
            * devtool - Elementsでどこか特定の要素にfocusしている時機能した
                * ただしどの要素かは覚えてない
* FirefoxではどのケースもNG(でも機能しないだけで実害なし)
    * ただし正直あまり深くは確認していない

とにかくこれはlocalStorage特有の症状なのはほぼ間違いない。一回でも処理が戻る箇所があればそこでブラウザが画面更新する。しかしlocalStorageは制御が戻らず一直線に処理するため画面更新されない。

> これだけ確認したのだから自分に非はないはず。ちょっとくやしいが、最悪5秒止まる程度なので許して...

------------------------------------------------------------------------

最初の起動時に単に空のデータベースを表示するのはやや不親切なので、次のように対応する。

* 起動時にデータベースをfetchし、結果が空の場合は次の通り対応
    * modalを表示して次のどちらかを選択
        * サンプルデータをロードして起動
        * 空のまま起動

------------------------------------------------------------------------

ひとつ不具合を発見。症状は次の通り。

* Artistをクリックで変更
* Releasesは最初の項目が選択された状態になる(しかし内部状態が不定らしい)
* ここでReleasesの項目はクリックせずに...
    * Releases - Editを実行するとEditではなくNewになる(不具合)
    * Releases - Deleteできない(これも不具合)
* 一方、一回Releasesの最初の項目をクリックしてから(これで内部状態が確定)
    * Releases - Editを実行するとEditになる
    * Releases - DeleteもOK
* 以上の症状はTracksでも同じように起こる

症状は突き止めたので落ち着いて修正する。これはRails版では発生しないため、やはりsyncイベント発生の前後による違いが原因と考えられる。どうやら次の部分らしい。

```
  syncFromParent: (owner) ->
    # owner変更時は@itemをリセット
    # (@itemが前のownerに属しているまま残っていると処理がおかしくなるため)
    # でもちょっと次の一行はおかしいかも...
    @item = null if owner       # ownerがいる場合は常にクリア
    if @items.setOwner owner    # 後でonSyncにcallbackされる(というのが誤り)
      @item = null              # その前にクリア...のつもりだが
                                # 実際にはonSyncはもう終わっている
      @onSync() unless owner    # ownerなしだとcallbackしないのでここで呼ぶ
```

setOwnerを呼ぶとその先でfetchを行いonSyncがcallbackされるが、localStorageの場合は後ではなくコールスタックの一番奥で直接コールされる。よって後で@item = nullするとかえっておかしくなる。

修正版は次の通り。一行目も意味が明解になるように変更した。

```
  syncFromParent: (owner) ->
    return if owner == @items.owner   # owner変更がなければskip(この方が明解)
    @item = null    # 前のownerに属している@itemはリセットする
    # setOwnerをコール -> その先でonSyncがcallback
    if @items.setOwner owner
      # ただしownerがない場合はcallbackされないのでここで直接呼び出す
      @onSync() unless owner?
```

------------------------------------------------------------------------

もうひとつ見つけた。

* Newした結果がselectされない
* Editして順序が変更された場合に反映(sort)されない

原因もすでに分っている(syncイベントの前後によるもの)。onUpdateでcallbackした時もういちど@onSync()を実行することで解決した。これだとonSyncを2度実行してしまうが、この程度なら効率上はほぼ無視できるのでよしとする。

> Backbone.LocalStorageではBackboneが想定しているメッセージ処理手順と異なる(syncの方がsortより先に終わってしまう)ので仕方ない。

------------------------------------------------------------------------

動作も十分安定してきたので、最後に一括処理の部分を最適化する。サンプルデータのロードと全消去に時間がかかるのはいちいちonSyncを呼んでいるためなので、これらの実行中だけonSyncを一時的に無効化する。

これははっきりと効果があり、今後は全て0.5s以内に終わるようになった。

------------------------------------------------------------------------

最後にminifyを追加して終了。次のnodeモジュールを使う。

* JavaScript - gulp-uglify
* CSS - gulp-ruby-sassのtypeオプションで対応
* JSON - gulp-jsonminify

> gulpだとあっという間にできる。gruntではこうはいかないだろう(たぶん今もまだGruntfileをいじっているのでは...)。

