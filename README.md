# インストールガイドと必要要件

## 必要なパッケージ
`T1wT2wProcessing.sh` スクリプトを実行するために必要なパッケージは以下の通りです：

- [ANTs](https://github.com/ANTsX/ANTs)：T2強調画像をT1強調画像に線形位置合わせするために使用します。
- [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)：頭蓋骨除去、セグメンテーション、リサンプリングなどの操作に使用します。
- [HCP Pipelines](https://github.com/Washington-University/HCPpipelines)：特に `BiasFieldCorrection_sqrtT1wXT2w.sh` スクリプトはバイアスフィールド補正に使用します。これはヒトコネクトームプロジェクトパイプラインの一部です。

## インストール手順

### 1. ANTs
ANTsをインストールするには、以下の手順に従ってください：

1. ANTsリポジトリをクローンします：
   ```bash
   git clone https://github.com/ANTsX/ANTs.git
   ```
2. ANTsディレクトリに移動し、ツールをコンパイルします：
   ```bash
   cd ANTs
   ./build.sh
   ```

詳細なインストール手順については、公式の [ANTsドキュメント](https://github.com/ANTsX/ANTs/wiki/Installing-ANTs) を参照してください。

### 2. FSL
FSLをインストールするには、以下の手順に従ってください：

1. 次のコマンドでFSLをダウンロードします：
   ```bash
   wget https://fsl.fmrib.ox.ac.uk/fsldownloads/fslinstaller.py
   ```
2. インストーラを実行します：
   ```bash
   python fslinstaller.py
   ```

詳細については、[FSLインストールガイド](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation) を参照してください。

### 3. HCP Pipelines
HCP Pipelines（特に `BiasFieldCorrection_sqrtT1wXT2w.sh`）をインストールするには：

1. リポジトリをクローンします：
   ```bash
   git clone https://github.com/Washington-University/HCPpipelines.git
   ```
2. HCP Pipelinesツールをパスに追加します：
   ```bash
   export PATH=$PATH:/path/to/HCPpipelines/global/scripts
   ```

`/path/to/HCPpipelines` をリポジトリをクローンした適切なディレクトリに置き換えてください。




# 使用方法

./T1wT2wProcessing.sh [--data-dir DATA_DIR] [--output-dir OUTPUT_DIR] --t1w-image T1W_IMAGE --t2w-image T2W_IMAGE

引数

--data-dir DATA_DIR: 入力データが格納されているディレクトリ（デフォルト: 現在のディレクトリ）。

--output-dir OUTPUT_DIR: 出力ファイルを保存するディレクトリ（デフォルト: 現在のディレクトリ）。

--t1w-image T1W_IMAGE: T1強調画像ファイル（必須）。

--t2w-image T2W_IMAGE: T2強調画像ファイル（必須）。

## 使用例

必要なT1wおよびT2w画像を指定し、データおよび出力ディレクトリを指定してスクリプトを実行する例:

./T1wT2wProcessing.sh --data-dir /path/to/data --output-dir /path/to/output --t1w-image t1w_image.nii.gz --t2w-image t2w_image.nii.gz

## 処理の説明

強度の不均一性補正: N4BiasFieldCorrectionを使用して、T1wおよびT2w画像の強度の不均一性を補正します。

線形レジストレーション: ANTsを使用して、T2w画像をT1w画像にレジストレーションし、整列させます。

頭蓋骨除去: FSLのbetコマンドを使用してT1w画像から脳領域を抽出し、バイナリマスクを作成します。

バイアスフィールド補正: BiasFieldCorrection_sqrtT1wXT2w.shスクリプトを使用してT1wとT2wのバイアスフィールド補正を適用します。

セグメンテーション: FSLのfastコマンドを使用して、T1w画像を白質および灰白質にセグメンテーションします。

スケーリングと比率計算: 組織コントラストを調べるために、sT1w/T2w比を計算します。
