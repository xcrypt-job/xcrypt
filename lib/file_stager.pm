package file_stager;

use File::Path;
use File::Copy;
use File::Spec;
use File::Basename;
use Cwd;
use xcropt;
use jsconfig;

sub new {
	my $class = shift;									#クラス名
	my $job = shift;									#ジョブオブジェクト
	my $stage_in_list = analyze_stage_in_files($job);	#ステージインファイルのハッシュリスト
	my $stage_out_list = analyze_stage_out_files($job);	#ステージアウトファイルのハッシュリスト
	my $stage_in_flag = 0;
	my $stage_out_flag = 0;
	my %cfg = %{$jsconfig::jobsched_config{$job->{env}->{sched}}};
	my $stage_in_zip_file = "stage_in_" . $job->{id} . ".zip";	#アーカイブファイル名(ステージイン)
	my $stage_out_zip_file = "stage_out_" . $job->{id} . ".zip";#アーカイブファイル名(ステージアウト)
	
	if(defined($job->{JS_stage_in_files})){
		$stage_in_flag = 1;
	}
	if(defined($job->{JS_stage_out_files})){
		$stage_out_flag = 1;
	}		
	my $staging_file_obj = {				
		"stage_in_list" => $stage_in_list,
		"stage_out_list"=> $stage_out_list,
		"id" => $job->{'id'},
		"stage_in_flag" => $stage_in_flag,
		"stage_out_flag" => $stage_out_flag,
		"stage_in_sub" => $cfg{stage_in_files},
		"stage_out_sub" => $cfg{stage_out_files},
		"stage_in_zip_file" => $stage_in_zip_file,
		"stage_out_zip_file" => $stage_out_zip_file,
	};
	bless $staging_file_obj;
	return $staging_file_obj;
}

###############################################################################
#   ＜＜ ジョブオブジェクトからのステージイン対象ファイルの取り出し ＞＞ 
#   ステージンインファイル('JS_stage_in_files')をハッシュのリストに格納して返す
###############################################################################
sub analyze_stage_in_files {
	my $job = shift;
	my @files = analyze($job, 'JS_stage_in_files');
	return \@files;
}

###############################################################################
#   ＜＜ ジョブオブジェクトからのステージアウト対象ファイルの取り出し ＞＞ 
#   ステージアウトファイル('JS_stage_out_files')をハッシュのリストに格納して返す
###############################################################################
sub analyze_stage_out_files {
	my $job = shift;
	my @files = analyze($job, 'JS_stage_out_files');
	return \@files;
}

###############################################################################
#   ＜＜ ジョブオブジェクトからのステージング対象ファイルの取り出し ＞＞ 
#   ステージングファイル('JS_stage_in_files'または'JS_stage_out_files')をハッシュのリストに格納して返す
###############################################################################
sub analyze{
	my $job = shift;	#ジョブオブジェクト
	my $key = shift;	#ステージインorステージアウトのキー
	my @result = ();	#返却するハッシュリスト

	# スカラーの時
	# 例：'JS_stage_in_files' => 'aaa, ../bbb, ./ccc/ddd,'
	if(ref(\$job->{$key}) eq 'SCALAR'){
		my @filename =  split(/\s*,\s*/,  $job->{$key});
		for(@filename){
			push(@result, {local_file => "$_", remote_file => "$_"})
		}	
	}
	# 配列の時
	elsif(ref($job->{$key}) eq 'ARRAY'){
		foreach my $val(@{$job->{$key}}){
			# 例：'JS_stage_in_files' => [{'local_file' => 'aaa', 'remote_file' => 'bbb'}]
			if(ref($val) eq 'HASH'){
				push(@result, {local_file => $val->{local_file}, remote_file => $val->{remote_file}});
			}
			# 例：'JS_stage_in_files' =>[sub{aaa$VALUE[0]}]
			elsif(ref($val) eq 'CODE'){
				push(@result, {local_file => &{$val}, remote_file => &{$val}});
			}
			# 例：'JS_stage_in_files' => ['./aaa', '../bbb', './ccc/ddd']
			elsif(ref(\$val) eq 'SCALAR'){
				push(@result, {local_file => $val, remote_file => $val});
			}else{
				#ファイルがないのでスルー
			}
		}
	}
	# サブルーチンの時
	# 例：'JS_stage_in_files' => sub{"aaa$VALUE[0]"}
	elsif(ref($job->{$key}) eq 'CODE'){
		push(@result, {local_file => &{$job->{$key}}, remote_file => &{$job->{$key}}});
	}else{
		die "Error in  $xcropt::options{sched}.pm";
	}

	return @result;
}

###############################################################################
#   ＜＜ ジョブ投入側におけるステージイン処理 ＞＞ 
#   ステージイン対象ファイルからアーカイブファイルを作成し
#   ジョブスケジューラにアーカイブファイル名を渡す
###############################################################################
sub stage_in_local{	
    my $self = shift;
    
	# ジョブオブジェクトからステージイン対象ファイル情報を受け取る
	my $stage_in_hash_list = $self->{'stage_in_list'};
	
	# ステージイン対象ファイル('local_file'のみ)を配列に入れる	
	my @stage_in_files = ();
	foreach my $ref_stage_in_hash(@{$stage_in_hash_list}) {
		my %stage_in_file = %{$ref_stage_in_hash};
		push(@stage_in_files, $stage_in_file{'local_file'});
	}

	# アーカイブファイルを置いておく一時ディレクトリの作成
	my $tmpdir = './' . $$ . '_' . $self->{id};
	mkpath($tmpdir);
	
	# ステージインファイルのシンボリックリンクを一時ディレクトリに作成
	my $jobdir = getcwd();
	my $index = 0;
	foreach my $stage_in_file(@stage_in_files){
		my @tmp_filelist = glob($stage_in_file);
		my @file_list = ();
		foreach my $tmp_file(@tmp_filelist){
			if(-f $tmp_file){
				push(@file_list, $tmp_file);
			}else{
				print STDERR "stage_in_file $tmp_file doesn't exist.\n";
			}
		}
	
		if(@file_list == 1){
			my $old_file = File::Spec->rel2abs($file_list[0]);
			chdir($tmpdir);
			symlink($old_file, $index);
			chdir($jobdir);
		}elsif(@file_list > 1){
			my $tmp_wild_dir = File::Spec->catfile( $tmpdir, $index );
			mkdir($tmp_wild_dir);
			foreach my $wildfile(@file_list){
				my $old_file = File::Spec->rel2abs($wildfile);
				chdir($tmp_wild_dir);
				symlink($old_file, basename($old_file));
				chdir($jobdir);
			}
		}
		++ $index;
	}

    # シンボリックリンクからzipファイルを作成
    chdir($tmpdir);
    my $args = join(' ', (0..$index-1));
    system("/usr/bin/zip $self->{stage_in_zip_file} -r $args >/dev/null 2>&1");
	chdir($jobdir);
	copy("$tmpdir/$self->{stage_in_zip_file}", ".");
	rmtree($tmpdir); 

	# ジョブスケジューラに転送ファイルリストを渡す
	my $filelist = $self->{"stage_in_zip_file"} . ',' .  $self->{id} . '_before_in_job.pl';
	if($self->{"stage_out_flag"}){
		$filelist .= ',' .  $self->{id} . '_after_in_job.pl';
	}
	if(defined($self->{"stage_in_sub"})){
		$self->{"stage_in_sub"}($filelist);
	}
	my $out_file_list ="";
	if($self->{"stage_out_flag"}){
		if(defined($self->{"stage_out_sub"})){
			$out_file_list .= $self->{"stage_out_zip_file"};
			$self->{"stage_out_sub"}($out_file_list);
		}
	}
}

###############################################################################
#   ＜＜ ジョブ実行計算機側におけるステージイン処理 ＞＞ 
#   ステージインアーカイブファイルを展開する文字列を返す。
#   当文字列は、before_in_job スクリプトの先頭に追加される。
###############################################################################
sub stage_in_job{
	my $self = shift;
	my $cmd = "";											#返却する文字列

	# ジョブオブジェクトからステージイン対象ファイル情報を受け取る
	my $stage_in_hash_list = $self->{'stage_in_list'};
	
	# ステージングファイルを'local_file''remote_file'の順に配列に入れる
	my @stage_in_files_list_array = ();
	foreach my $stage_in_ref_hash(@{$stage_in_hash_list}){
		my %stage_in_hash = %{$stage_in_ref_hash};
		push(@stage_in_files_list_array, "$stage_in_hash{local_file} $stage_in_hash{remote_file}");  
	}
	
	# ステージインアーカイブファイルを展開する文字列の作成
	my $stage_in_files_list_text = join(',', map {"'" . $_ . "'";} @stage_in_files_list_array);
$cmd .= <<__STAGE_IN_SCRIPT__;
{
use File::Path;
use File::Copy;
use File::Basename;
use File::Spec;
use Cwd;
my \$jobdir = getcwd();
my \$tmpdir = "./" . \$\$ . "_" . $self->{id};
mkdir(\$tmpdir, 0777);
move("$self->{stage_in_zip_file}", "\$tmpdir");
chdir(\$tmpdir);
system("/usr/bin/unzip $self->{stage_in_zip_file} >/dev/null 2>&1");
chdir(\$jobdir);
my \$index = 0;

foreach my \$stage_in_file_pair ($stage_in_files_list_text){
	my \@stage_in_file_list = split(/ /, \$stage_in_file_pair);
	my \@file_list = glob(\$stage_in_file_list[0]);
	if(\@file_list == 1){
		my \$new_file = File::Spec->rel2abs(\$stage_in_file_list[1]);
		my \$arrange_dir = dirname(\$stage_in_file_list[1]);
		unless(-d \$arrange_dir){
			mkpath(\$arrange_dir);
		}
		chdir(\$tmpdir);
		move(\$index, \$new_file);
		chdir(\$jobdir);
	}elsif(\@file_list > 1){
		my \$new_file = File::Spec->rel2abs(\$stage_in_file_list[1]);
		unless(-d \$stage_in_file_list[1]){
			mkpath(\$stage_in_file_list[1]);
		}
		foreach my \$wildfile(\@file_list){
			my \$wild_tmp_dir = File::Spec->catfile( \$tmpdir, \$index );
			chdir(\$wild_tmp_dir);
			move(\$wildfile, \$new_file);
			chdir(\$jobdir);
		}
	}
	++ \$index;
}
rmtree(\$tmpdir);
}
__STAGE_IN_SCRIPT__
	return $cmd;	
}

###############################################################################
#   ＜＜ ジョブ実行計算機側におけるステージアウト処理 ＞＞ 
#   ステージアウト対象ファイルリストをアーカイブする文字列を返す。
#   当文字列は、after_in_job スクリプトの末尾に追加される。
###############################################################################
sub stage_out_job{
    my $self = shift;
    my $cmd = "";												# 返却する文字列
	
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
{
use File::Path;
use File::Copy;
use File::Spec;
use File::Basename;
use Cwd;
my \$jobdir = Cwd::getcwd();
my \$tmpdir = "./" . \$\$ . "_" . $self->{id};
mkdir(\$tmpdir, 0777);
my \$index = 0;
foreach my \$stage_out_file($stage_out_files_list_text) {
	my \@tmp_file_list = glob(\$stage_out_file);
	my \@file_list = ();
	foreach my \$tmp_file(\@tmp_file_list) {
		if(-f \$tmp_file) {
			push(\@file_list, \$tmp_file);
		}
		else {
			print STDERR "stage_out_file '\$tmp_file' doesn't exist.\\n";
		}
	}

	if(\@file_list == 1) {
		my \$old_file = File::Spec->rel2abs(\$file_list[0]);
		chdir(\$tmpdir);
		symlink(\$old_file, \$index);
		chdir(\$jobdir);
	}
	elsif(\@file_list  > 1) {
		my \$wild_tmp_dir = File::Spec->catfile( \$tmpdir, \$index );
		mkdir(\$wild_tmp_dir);
		foreach my \$wildfile(\@file_list) {
			my \$old_file = File::Spec->rel2abs(\$wildfile);
			chdir(\$wild_tmp_dir);
			symlink(\$old_file, basename(\$old_file));
			chdir(\$jobdir);
		}
	}

	++ \$index;
}

chdir(\$tmpdir);
my \$args = join(' ', (0..\$index-1));
system("/usr/bin/zip $self->{stage_out_zip_file} -r \$args >/dev/null 2>&1");
chdir(\$jobdir);
copy("\$tmpdir/$self->{stage_out_zip_file}", ".");
rmtree(\$tmpdir);
}
__STAGE_OUT_SCRIPT__

    return $cmd;
}

###############################################################################
#   ＜＜ ジョブ投入側におけるステージアウト処理 ＞＞ 
#   ステージアウトアーカイブファイルを展開する。
###############################################################################
sub stage_out_local{
	my $self = shift;
	
	# ジョブオブジェクトからステージイン対象ファイル情報を受け取る
	my $stage_out_hash_list = $self->{'stage_out_list'};
	
	# アーカイブファイルを展開する一時ディレクトリの作成
	my $tmpdir = './' . $$ . '_' . $self->{id};
	mkdir($tmpdir, 0777);

	# アーカイブファイルを一時ディレクトリに移動
	move("$self->{stage_out_zip_file}", "$tmpdir/");

	# アーカイブファイルの展開
	my $jobdir = getcwd();
	chdir($tmpdir);
	system("/usr/bin/unzip $self->{stage_out_zip_file} >/dev/null 2>&1");
	chdir($jobdir);
	
	# 各ファイルの配置
	my $index = 0;
	foreach my $ref_stage_out_file(@{$stage_out_hash_list}){
		my %stage_out_file = %{$ref_stage_out_file};
		if(-f $tmpdir . '/' . $index){
			my $new_file = File::Spec->rel2abs($stage_out_file{'local_file'});
			my $arrange_dir = dirname($new_file);
			unless(-d $arrange_dir){
				mkpath($arrange_dir);
			}
			chdir($tmpdir);
			move($index, $new_file);
			chdir($jobdir);
		}
		elsif(-d $tmpdir . '/' . $index){
			my $new_dir = File::Spec->rel2abs($stage_out_file{'local_file'});
			mkpath($new_dir);
			my $wild_tmp_dir = File::Spec->catfile( $tmpdir, $index );
			chdir($wild_tmp_dir);
			my @filelist = glob("./*");
			foreach my $wildfile(@filelist){
				if(-f $wildfile){
					move($wildfile, $new_dir);
				}elsif(-d $wildfile){
					print "in stagingfile mix directory\n";
				}
			}
			chdir($jobdir);
		}
		++ $index;
	}

	# 一時ディレクトリを削除
	rmtree($tmpdir);

}

###############################################################################
#   ＜＜ ジョブ投入側におけるステージアウト処理 ＞＞ 
#   ステージアウトアーカイブファイルを展開する。
###############################################################################
sub dispose{
	my $self = shift;
	if(-f $self->{stage_in_zip_file}){
		unlink($self->{stage_in_zip_file});
	}
	if(-f $self->{stage_out_zip_file}){
		unlink($self->{stage_out_zip_file});
	}
}

1;

