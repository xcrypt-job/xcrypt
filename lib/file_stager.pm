package file_stager;

use strict;
use NEXT;
use builtin;
use File::Path;
use File::Copy;
use File::Spec;
use File::Basename;
use Cwd;
use xcropt;
use jsconfig;

&add_key('JS_stage_in_files', 'JS_stage_out_files');

## 作成したzipファイル名のリスト
our %all_zip_file_list = ();

# コンストラクタ
sub new {
	my $class = shift;												# クラス名
	my $self = $class->NEXT::new(@_);								# オブジェクト作成
	my $staging_base_dir = "";										# ステージング基準ディレクトリ
	my %cfg = %{$jsconfig::jobsched_config{$self->{env}->{sched}}};	# スケジューラオブジェクト

	# ステージングファイルをハッシュのリストに格納
	if(defined($self->{JS_stage_in_files})){
		$self->{stage_in_list} = analyze($self->{JS_stage_in_files}, 'in', @{$self->{VALUE}});
	}
	if(defined($self->{JS_stage_out_files})){
		$self->{stage_out_list} = analyze($self->{JS_stage_out_files}, 'out', @{$self->{VALUE}});
	}
	
	# ステージングベースディレクトリの確認
	if(defined($self->{JS_staging_base_dir})){
		$staging_base_dir = $self->{JS_staging_base_dir};
	}elsif(defined($cfg{staging_base_dir})){
		$staging_base_dir = $cfg{staging_base_dir};
	}else{
		$staging_base_dir = '.';
	}
	$self->{staging_base_dir} = $staging_base_dir;

	# アーカイブファイル名
	$self->{stage_in_zip_file} = "stage_in_" . $self->{id} . ".zip";
	$self->{stage_out_zip_file} = "stage_out_" . $self->{id} . ".zip";

	# ジョブスケジューラにファイル転送機能があるかの確認
	$self->{stage_in_files_set} = $cfg{stage_in_files};
	$self->{stage_out_files_set}= $cfg{stage_out_files};

	# 初期化完了フラグ
	$self->{file_stager_initialized} = 1;

	return bless $self, $class;
}

#####################################################################################
##  ファイルステージング前処理
##  stage_in_local:ステージインアーカイブファイル作成
#####################################################################################
sub before {
	my $self = shift;
	# stage_in_localの呼び出し
	stage_in_local($self);
}

#####################################################################################
##  ファイルステージングジョブ内前処理
##  stage_in_job  :ステージインファイルの配置処理スクリプトを
##                 before_in_jobの先頭に追加
#####################################################################################
sub make_before_in_job_script {
    my $self = shift;
    $self->core::make_before_in_job_script();
    # ステージインファイルの配置処理スクリプトを追加
    if(defined($self->{stage_in_list})){
	    @{$self->{before_in_job_script}} = (@{stage_in_job($self)}, @{$self->{before_in_job_script}});
    }
}

####################################################################################
##  ファイルステージングジョブ内後処理
##  stage_out_job :ステージアウトアーカイブファイル作成スクリプトを
##                 after_in_jobスクリプトの末尾に追加
####################################################################################
sub make_after_in_job_script {
    my $self = shift;
    $self->core::make_after_in_job_script();
    # ステージアウトアーカイブファイル作成スクリプトを追加
    if(defined($self->{stage_out_list})){
    	@{$self->{after_in_job_script}} = (@{$self->{after_in_job_script}}, @{stage_out_job($self)});
    }
}

#################################################################################
##  ファイルステージングの後処理
##  stage_out_local:ステージアウトファイルの配置
#################################################################################
sub after {
	my $self = shift;
	# stage_out_localの呼び出し
	stage_out_local($self);
}

###############################################################################
#   ファイルステージングにおいてできたアーカイブファイルを削除する
###############################################################################
sub finally{
	my $self = shift;

	# コンストラクタの実行確認
	unless(defined($self->{file_stager_initialized})) {
		unless(defined($self->{package_err_displayed}))
		{
			warn "There is a possibility that the order of the module is wrong\n";
			$self->{package_err_displayed} = 1;
		}
		return;
	}

	# ステージインアーカイブファイルの削除
	my $stage_in_zip_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_zip_file});
	if(-f $stage_in_zip_file){
		unlink($stage_in_zip_file);
		delete($all_zip_file_list{$self->{stage_in_zip_file}});
	}

	# ステージアウトアーカイブファイルの削除
	my $stage_out_zip_file = $self->{stage_out_zip_file};
	if(-f $stage_out_zip_file){
		unlink($stage_out_zip_file);
		delete($all_zip_file_list{$self->{stage_out_zip_file}});
	}
}

#######################################################################################################
#  シグナルハンドリング
#  一時ファイルを削除する
#######################################################################################################
sub sigint_handler {
	foreach my $zip_file(keys %all_zip_file_list){
		if(-f $zip_file){
			unlink($zip_file);
		}
	}
}
sub sigterm_handler{
	foreach my $zip_file(keys %all_zip_file_list){
		if(-f $zip_file){
			unlink($zip_file);
		}
	}
}

########################################################################################################
##  ステージングファイル('JS_stage_in_files'または'JS_stage_out_files')をハッシュのリストに格納して返す
##  ステージングファイルとステージングの種類とRANGEの変化値を受け取る
########################################################################################################
sub analyze{
	my $stage_files = shift;	# ステージングファイル
	my $stage_type = shift;		# ステージングの種類（ステージインorステージアウト）
	local @user::VALUE = @_;	# RANGEの範囲
	my $former = "";			# 転送元
	my $ahead = "";				# 転送先
	my @stage_hash_list = ();	# 返却するハッシュリスト

	# ステージイン、ステージアウトの確認
	if($stage_type eq 'in'){
		$former = "local_file";
		$ahead = "remote_file";
	}elsif($stage_type eq 'out'){
		$former = "remote_file";
		$ahead = "local_file";
	}

	# アレイ
	if(ref($stage_files) eq 'ARRAY'){
		# サブルーチンとスカラーで構成されているか確認
		my $sub_or_scalar_flag = 1;
		for my $element(@{$stage_files}){
			if(ref($element) ne 'CODE' and ref(\$element) ne 'SCALAR'){
				$sub_or_scalar_flag = 0;
				last;
			}
		}
		# 全てスカラーとサブルーチン		
		if($sub_or_scalar_flag == 1){
			my $file_count = @{$stage_files};
			# 1個以上
			if($file_count > 1){
				my $directory = "";
				if(ref(@{$stage_files}[$file_count-1]) eq 'CODE'){
					$directory = &{@{$stage_files}[$file_count-1]};
				}elsif(ref(\@{$stage_files}[$file_count-1]) eq 'SCALAR'){
					$directory = @{$stage_files}[$file_count-1];
				}
				for(my $i = 0; $i < $file_count-1; $i++){
					if(ref(@{$stage_files}[$i]) eq 'CODE'){	
						push(@stage_hash_list, {$former => &{@{$stage_files}[$i]}, $ahead => $directory});
					}elsif(ref(\@{$stage_files}[$i]) eq 'SCALAR'){
						push(@stage_hash_list, {$former => @{$stage_files}[$i], $ahead => $directory});
					}
				}
			}
			# 1個
			elsif($file_count == 1){
				if(ref(@{$stage_files}[0]) eq 'CODE'){
					push(@stage_hash_list, {$former => &{@{$stage_files}[0]}, $ahead => &{@{$stage_files}[0]}});
				}elsif(ref(\@{$stage_files}[0]) eq 'SCALAR'){
					if(@{$stage_files}[0] =~ /\*|\?/){
						my $directory = dirname(@{$stage_files}[0]);
						push(@stage_hash_list, {$former => @{$stage_files}[0], $ahead => $directory});
					}
					else{
						push(@stage_hash_list, {$former => @{$stage_files}[0], $ahead => @{$stage_files}[0]});
					}
				}
			}
			else{
				warn "It is a description outside specification\n";
				return;
			}
		}
		# それ以外
		elsif($sub_or_scalar_flag == 0){
			foreach my $element(@{$stage_files}){
				# アレイ
				if(ref($element) eq 'ARRAY'){
					my $file_count = @{$element};
					# 1個以上
					if($file_count > 1){
						my $directory = "";		# 転送先ディレクトリ
						if(ref(@{$element}[$file_count-1]) eq 'CODE'){
							$directory = &{@{$element}[$file_count-1]};
						}elsif(ref(\@{$element}[$file_count-1]) eq 'SCALAR'){
							$directory = @{$element}[$file_count-1];
						}
						for(my $i = 0; $i < $file_count-1; $i++){
							if(ref(@{$element}[$i]) eq 'CODE'){
								push(@stage_hash_list, {$former => &{@{$element}[$i]}, $ahead => $directory});
							}elsif(ref(\@{$element}[$i]) eq 'SCALAR'){
								push(@stage_hash_list, {$former => @{$element}[$i], $ahead => $directory});
							}
						}
					}
					# 1個
					elsif($file_count == 1){
						if(ref(@{$element}[0]) eq 'CODE'){
							push(@stage_hash_list, {$former => &{@{$element}[0]}, $ahead => &{@{$element}[0]}});
						}elsif(ref(\@{$element}[0]) eq 'SCALAR'){
							if(@{$element}[0] = ~ /\*|\?/){
								my $directory = dirname(@{$element}[0]);
								push(@stage_hash_list, {$former => @{$element}[0], $ahead => $directory});
							}else{
								push(@stage_hash_list, {$former => @{$element}[0], $ahead => @{$element}[0]});
							}
						}
					}
					else{
						warn "It is a description outside specification \n";
						return;
					}
				}
				# ハッシュ
				elsif(ref($element) eq 'HASH'){
					if($element->{local_file} && $element->{remote_file}){
						if(ref($element->{local_file}) eq 'CODE' and ref($element->{remote_file}) eq 'CODE'){
							push(@stage_hash_list, {local_file => &{$element->{local_file}}, remote_file => &{$element->{remote_file}}});
						}elsif(ref($element->{local_file}) eq 'CODE'){
							push(@stage_hash_list, {local_file => &{$element->{local_file}}, remote_file => $element->{remote_file}});
						}elsif(ref($element->{remote_file}) eq 'CODE'){
							push(@stage_hash_list, {local_file => $element->{local_file}, remote_file => &{$element->{remote_file}}});
						}else{
							push(@stage_hash_list, {local_file => $element->{local_file}, remote_file => $element->{remote_file}});
						}
					}
				}
				# スカラー
				elsif(ref(\$element) eq 'SCALAR'){
					if($element =~ /\*|\?/){
						my $directory = dirname($element);
						push(@stage_hash_list, {$former => $element, $ahead => $directory});
					}else{
						push(@stage_hash_list, {$former => $element, $ahead => $element});
					}
				}
				# サブルーチン
				elsif(ref($element) eq 'CODE'){
					push(@stage_hash_list, {$former => &{$element}, $ahead => &{$element}});
				}
				else{
					warn "It is a description outside specification \n";
					return;
				}
			}
		}
	}
	# サブルーチン
	elsif(ref($stage_files) eq 'CODE'){
		my @file_list = &{$stage_files};
		my $file_count = @file_list;
		if($file_count > 1){
			for(my $i = 0; $i < $file_count -1; $i++){
				push(@stage_hash_list, {$former => $file_list[$i], $ahead => $file_list[$file_count - 1]});
			}
		}
		elsif($file_count == 1){
			push(@stage_hash_list, {$former => &{$stage_files}, $ahead => &{$stage_files}});
		}
	}
	# スカラ	
	elsif(ref(\$stage_files) eq 'SCALAR'){
		my @file_list =  split(/\s*,\s*/,  $stage_files);
		my $file_count = @file_list;
		if($file_count > 1){
			for(my $i = 0; $i < $file_count -1; $i++){
				push(@stage_hash_list, {$former => $file_list[$i], $ahead => $file_list[$file_count - 1]});
			}
		}
		elsif($file_count == 1){
			if($file_list[0] =~ /\*|\?/){
				my $directory = dirname($file_list[0]);
				push(@stage_hash_list, {$former => $file_list[0], $ahead => $directory});
			}else{
				push(@stage_hash_list, {$former => $file_list[0], $ahead => $file_list[0]});
			}
		}
	}
	else{
		warn "It is a description outside specification \n";
		return;
	}

	return \@stage_hash_list;
}

###############################################################################
#   ＜＜ ジョブ投入側におけるステージイン処理 ＞＞ 
#   ステージイン対象ファイルからアーカイブファイルを作成し
#   ジョブスケジューラにアーカイブファイル名を渡す
###############################################################################
sub stage_in_local{	
    my $self = shift;
    
    # コンストラクタの実行確認
	unless(defined($self->{file_stager_initialized})) {
		unless(defined($self->{package_err_displayed}))
		{
			warn "There is a possibility that the order of the module is wrong\n";
			$self->{package_err_displayed} = 1;
		}
		return;
	}

	# バルクを使用した場合
	# 子ジョブのステージングファイルを親ジョブに追加
	if($self->{bulked_jobs}){
		foreach my $bulk_hash(@{$self->{bulked_jobs}}){
			if(defined($bulk_hash->{stage_in_list})){
				push(@{$self->{stage_in_list}}, @{$bulk_hash->{stage_in_list}});
			}
			if(defined($bulk_hash->{stage_out_list})){
				push(@{$self->{stage_out_list}}, @{$bulk_hash->{stage_out_list}});
			}
		}
	}

	# ステージインの処理
	if(defined($self->{stage_in_list})) {
		# ジョブオブジェクトからステージイン対象ファイル情報を受け取る
		my $stage_in_hash_list = $self->{'stage_in_list'};

		# ステージイン対象ファイル('local_file'のみ)を配列に入れる	
		my @stage_in_files = ();
		foreach my $ref_stage_in_hash(@{$stage_in_hash_list}) {
			my %stage_in_file = %{$ref_stage_in_hash};
			push(@stage_in_files, $stage_in_file{'local_file'});
		}
		
		# アーカイブファイルを置いておく一時ディレクトリの作成
		my $tmpdir = $$ . '_' . $self->{id};
		mkdir($tmpdir);
		unless(-d $tmpdir) {
			warn "Cannot create the tmpdir '$tmpdir' at $self->{id}_stage_in\n";
			return;
		}
		
		# ステージインファイルのシンボリックリンクを一時ディレクトリに作成
		my $jobdir = getcwd();
		my $index = 0;
		my $is_exists_stage_in_file = 0;	# ステージイン対象ファイルが１つでもある場合に1
		foreach my $stage_in_file(@stage_in_files){
			my @tmp_filelist = glob($stage_in_file);
			my @file_list = ();
			# ファイルの有無の確認
			foreach my $tmp_file(@tmp_filelist){
				if(-f $tmp_file){
					push(@file_list, $tmp_file);
				}else{
					warn "stage_in_file $tmp_file doesn't exist at $self->{id}_stage_in\n";
				}
			}
			# シンボリックリンクの作成
			my $tmp_index_dir = File::Spec->catfile( $tmpdir, $index );
			mkdir($tmp_index_dir);
			foreach my $stage_file(@file_list){
				my $former_file = File::Spec->rel2abs($stage_file);
				chdir($tmp_index_dir);
				symlink($former_file, basename($former_file));
				chdir($jobdir);
				$is_exists_stage_in_file = 1;
			}
			++ $index;
		}

		# ステージイン対象ファイルが１つでもある場合
		my $stage_in_zip_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_zip_file});
		if($is_exists_stage_in_file) {
			# シグナルハンドリング処理用にファイル名を記憶
			$all_zip_file_list{$stage_in_zip_file} = '';
		    
		    # シンボリックリンクからzipファイルを作成
		    chdir($tmpdir);
		    my $args = join(' ', (0..$index-1));
		    system("/usr/bin/zip $self->{stage_in_zip_file} -r $args >/dev/null 2>&1");
			chdir($jobdir);
			move("$tmpdir/$self->{stage_in_zip_file}", "$self->{workdir}");
		}
		else {
			warn "Any staging object file doesn't exist at $self->{id}_stage_in\n";
		}
		rmtree($tmpdir); 
	}

	# ジョブスケジューラにステージインIFの定義がある場合、転送ファイルリストを渡す
	if(defined($self->{"stage_in_files_set"})) {
		my $stage_in_zip_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_zip_file});
		my @file_list = ();
		if(-f $stage_in_zip_file) {
			push(@file_list, $self->{stage_in_zip_file});
		}
		push(@file_list, $self->{before_in_job_file});
		if(defined($self->{stage_out_list})){
			push(@file_list, $self->{after_in_job_file});
		}
		if(@file_list > 0) {
			$self->{"stage_in_files_set"}(@file_list);
		}
	}
	
	# ジョブスケジューラにステージアウトIFの定義がある場合、転送ファイルリストを渡す
	if(defined($self->{"stage_out_files_set"})) {
		my @file_list = ();
		my $running_file = $self->{id} . "_is_running";
		push(@file_list, $running_file);
		my $done_file = $self->{id} . "_is_done";
		push(@file_list, $done_file);
		# ステージアウトの処理
		if(defined($self->{stage_out_list})) {
			# シグナルハンドリング処理用にファイル名を記憶
			$all_zip_file_list{$self->{stage_out_zip_file}} = '';
			push(@file_list, $self->{"stage_out_zip_file"});
		}
		$self->{"stage_out_files_set"}(@file_list);
	}
}

###############################################################################
#   ＜＜ ジョブ実行計算機側におけるステージイン処理 ＞＞ 
#   ステージインアーカイブファイルを展開する文字列を返す。
#   当文字列は、stage_in_job スクリプトになる。
###############################################################################
sub stage_in_job{
	my $self = shift;
	my $cmd = "";		#返却する文字列

	# ジョブオブジェクトからステージイン対象ファイル情報を受け取る
	my $stage_in_hash_list = $self->{'stage_in_list'};
	
	# ステージングファイルの'remote_file'を配列に入れる
	my @stage_in_files = ();
	foreach my $stage_in_ref_hash(@{$stage_in_hash_list}){
		my %stage_in_hash = %{$stage_in_ref_hash};
		push(@stage_in_files, $stage_in_hash{remote_file});  
	}
	
	# 対象ファイルが無い場合は空文字列を返す
	if(@stage_in_files <= 0) {
		return $cmd;
	}

	# ステージインアーカイブファイルを展開する文字列の作成
	my $stage_in_files_list_text = join(',', map {"'" . $_ . "'";} @stage_in_files);
$cmd .= <<__STAGE_IN_SCRIPT__;
use File::Path;
use File::Copy;
use File::Basename;
use File::Spec;
use Cwd;

my \$jobdir = getcwd();
unless(-f "$self->{stage_in_zip_file}") {
	warn "'$self->{stage_in_zip_file}' not found\\n";
}
chdir("$self->{staging_base_dir}") or warn "failed to chdir '$self->{staging_base_dir}': \$!\\n";
unless(-f "$self->{stage_in_zip_file}"){
	chdir(\$jobdir) or warn "failed to chdir '\$jobdir': \$!\\n";
	move("$self->{stage_in_zip_file}", "$self->{staging_base_dir}") or warn "failed to move. from '$self->{stage_in_zip_file}' to '$self->{staging_base_dir}'.\\n";
	chdir("$self->{staging_base_dir}");
}
my \$tmpdir = \$\$ . '_' . $self->{id};
mkdir(\$tmpdir, 0777) or warn "Failed to create the directory '\$tmpdir': \$!\\n";
move("$self->{stage_in_zip_file}", "\$tmpdir");
chdir(\$tmpdir);
system("/usr/bin/unzip $self->{stage_in_zip_file} >/dev/null 2>&1");
unless(-d "0/"){
	warn "Cannot Decompression the zipfile '$self->{stage_in_zip_file} at $self->{id}_stage_in'\\n";
}
chdir(\$jobdir);
my \$index = 0;

foreach my \$stage_in_file ($stage_in_files_list_text){
	chdir("$self->{staging_base_dir}");
	if(\$stage_in_file eq ''){
		warn "The forwarding site is empty at $self->{id}_stage_in\\n";
	}
	else{
		my \$tmp_index_dir = File::Spec->catfile("\$tmpdir", \$index );
		my \$ahead = File::Spec->rel2abs(\$stage_in_file);
		if(\$stage_in_file =~ /\\/\$/){
			\$ahead = \$ahead . '/';
		}
		my \$result = chdir(\$tmp_index_dir);
		if(\$result == 1){
			my \@filelist = glob("./*");
			if(\@filelist == 0){
				warn "The zip file is empty at $self->{id}_stage_in\\n";
			}
			foreach my \$stage_file(\@filelist){
				if(-f \$stage_file){
					move(\$stage_file, \$ahead) or warn "Failed to stage in '\$stage_file': \$!\\n";
				}
			}
		}
	}
	chdir(\$jobdir);
	++ \$index;
}
chdir("$self->{staging_base_dir}");
rmtree(\$tmpdir);
chdir(\$jobdir);
0;
__STAGE_IN_SCRIPT__
	my @cmd = split(/\n/, $cmd);
	return \@cmd;
}

###############################################################################
#   ＜＜ ジョブ実行計算機側におけるステージアウト処理 ＞＞ 
#   ステージアウト対象ファイルリストをアーカイブする文字列を返す。
#   当文字列は、stage_out_jobスクリプトになる
###############################################################################
sub stage_out_job{
    my $self = shift;
    my $cmd = "";		# 返却する文字列
	
	# ジョブオブジェクトからステージアウト対象ファイル情報を受け取る
	my $stage_out_hash_list = $self->{'stage_out_list'};
	
	# ステージアウト対象ファイル('remote_file'のみ)を配列に入れる
	my @stage_out_files = ();
	foreach my $ref_stage_out_hash(@{$stage_out_hash_list}) {
		my %stage_out_file = %{$ref_stage_out_hash};
		push(@stage_out_files, $stage_out_file{'remote_file'});
	}

	# 対象ファイルが無い場合は空文字列を返す
	if(@stage_out_files <= 0) {
		return $cmd;
	}

	# ステージアウトファイルをアーカイブするスクリプト文字列の作成
	my $stage_out_files_list_text = join(',', map {"'" . $_ . "'";} @stage_out_files);
$cmd .= <<__STAGE_OUT_SCRIPT__;
use File::Path;
use File::Copy;
use File::Spec;
use File::Basename;
use Cwd;
my \$jobdir = Cwd::getcwd();
chdir("$self->{staging_base_dir}") or die "Failed to chdir '$self->{staging_base_dir}': \$!\\n";
my \$tmpdir = \$\$ . "_" . $self->{id};
\$tmpdir = File::Spec->rel2abs(\$tmpdir);
mkdir(\$tmpdir, 0777) or die "Failed to create the directory '\$tmpdir': \$!\\n";
chdir(\$jobdir);
my \$index = 0;

my \$exists_stage_out_file = 0;
foreach my \$stage_out_file($stage_out_files_list_text) {
	chdir("$self->{staging_base_dir}");
	my \@tmp_file_list = glob(\$stage_out_file);
	my \@file_list = ();
	foreach my \$tmp_file(\@tmp_file_list) {
		if(-f \$tmp_file) {
			push(\@file_list, \$tmp_file);
		}
		else {
			warn "stage_out_file '\$tmp_file' doesn't exist\\n";
		}
	}

	my \$tmp_index_dir = File::Spec->catfile( \$tmpdir, \$index );
	mkdir(\$tmp_index_dir);
	foreach my \$stage_file(\@file_list) {
		my \$former_file = File::Spec->rel2abs(\$stage_file);
		chdir(\$tmp_index_dir);
		symlink(\$former_file, basename(\$former_file));
		chdir(\$jobdir);
		\$exists_stage_out_file = 1;
	}
	++ \$index;
}
if(\$exists_stage_out_file) {
	chdir(\$tmpdir);
	my \$args = join(' ', (0..\$index-1));
	system("/usr/bin/zip $self->{stage_out_zip_file} -r \$args >/dev/null 2>&1");
	if(-f "$self->{stage_out_zip_file}"){
		chdir(\$jobdir);
		move("\$tmpdir/$self->{stage_out_zip_file}", ".") or warn "Failed to create the zip file '$self->{stage_out_zip_file}'\\n";
		chdir("$self->{staging_base_dir}");
	}
	else{
		warn "Cannot create the zipfile '$self->{stage_out_zip_file}'\\n";
	}
	chdir(\$jobdir);
}
else {
	warn "Any staging object file doesn't exist\\n";
}
rmtree(\$tmpdir);
0;
__STAGE_OUT_SCRIPT__
    my @cmd = split(/\n/, $cmd);
	return \@cmd;
}

###############################################################################
#   ＜＜ ジョブ投入側におけるステージアウト処理 ＞＞ 
#   ステージアウトアーカイブファイルを展開する。
###############################################################################
sub stage_out_local{
	my $self = shift;
	unless(defined($self->{file_stager_initialized})) {
		unless(defined($self->{package_err_displayed}))
		{
			warn "There is a possibility that the order of the module is wrong\n";
			$self->{package_err_displayed} = 1;
		}
		return;
	}

	if(defined($self->{stage_out_list})) {
		my $jobdir = getcwd();

		# ジョブオブジェクトからステージアウト対象ファイル情報を受け取る
		my $stage_out_hash_list = $self->{'stage_out_list'};

		# ステージイン対象ファイル('local_file'のみ)を配列に入れる	
		my @stage_out_files = ();
		foreach my $ref_stage_out_hash(@{$stage_out_hash_list}) {
			my %stage_out_file = %{$ref_stage_out_hash};
			push(@stage_out_files, $stage_out_file{'local_file'});
		}

		# ジョブディレクトリへアーカイブファイルを移動		
		chdir("$self->{workdir}");
		if(-f "$self->{stage_out_zip_file}"){
			move("$self->{stage_out_zip_file}", "$jobdir");
		}
		chdir($jobdir);
		chdir($self->{staging_base_dir});
		if(-f $self->{stage_out_zip_file}){
			move("$self->{stage_out_zip_file}", "$jobdir");
		}
		chdir($jobdir);

		# アーカイブファイルの存在有無を確認
		unless(-f $self->{stage_out_zip_file}) {
			warn "'$self->{stage_out_zip_file}' not found\n";
			return;
		}

		# アーカイブファイルを展開する一時ディレクトリの作成
		my $tmpdir = $$ . '_' . $self->{id};
		mkdir($tmpdir, 0777);
		unless(-d $tmpdir) {
			warn "Cannot create the tmpdir '$tmpdir' at $self->{id}_stage_out\n";
			return;
		}
		# アーカイブファイルを一時ディレクトリに移動
		move("$self->{stage_out_zip_file}", "$tmpdir") or warn "Failed to move '$self->{stage_out_zip_file}': $! at $self->{id}_stage_out\n";
		
		# アーカイブファイルの展開
		chdir($tmpdir);
		system("/usr/bin/unzip $self->{stage_out_zip_file}>/dev/null 2>&1");
		unless(-d "0/"){
			warn "Cannot Decompression the zipfile '$self->{stage_out_zip_file} at $self->{id}_stage_out'\n";
		}
		chdir($jobdir);
		
		# 各ファイルの配置
		my $index = 0;
		foreach my $stage_out_file(@stage_out_files){
			if($stage_out_file eq ''){
				warn "The forwarding site is empty at $self->{id}_stage_out\n";
			}
			else{
				my $ahead = File::Spec->rel2abs($stage_out_file);
				if($stage_out_file =~ /\/$/){
					$ahead = $ahead . '/';
				}
				my $tmp_index_dir = File::Spec->catfile( $tmpdir, $index );
				my $result = chdir($tmp_index_dir);
				if($result == 1){
					my @filelist = glob("./*");
					if(@filelist == 0){
						warn "The zip file is empty at $self->{id}_stage_out\n";
					}
					foreach my $stage_file(@filelist){
						if(-f $stage_file){
							move($stage_file, $ahead) or warn "Failed to stage out '$stage_file': $! at $self->{id}_stage_out\n";
						}
					}
				}
			}
			++ $index;
			chdir($jobdir);
		}	
		# 一時ディレクトリを削除
		rmtree($tmpdir);
	}
}

1;
