# インストールガイドと必要要件

## 必要なパッケージ
`brain_image_processing.sh` スクリプトを実行するために必要なパッケージは以下の通りです：

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

## 環境の設定


 必要なすべてのツール（`N4BiasFieldCorrection`、`antsRegistration`、`bet`、`fslmaths`、`fast`）がシステムパスにあり、実行可能であることを確認してください。



