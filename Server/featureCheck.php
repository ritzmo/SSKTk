<?php
	$dbname = "database";
	$user = "username";
	$password = "password";
	
	header('Content-Type: text/plain'); 
	
    // Connect to database server
    $hd = mysql_connect("localhost", $user, $password)
          or die ("Unable to connect");

    // Select database
    mysql_select_db ($dbname, $hd)
          or die ("Unable to select database");

	$prod = mysql_real_escape_string($_POST['productid']);
	$udid = mysql_real_escape_string($_POST['udid']);
    $res = mysql_query("SELECT * FROM requests where udid='$udid' AND productid='$prod' AND status = 1",$hd) or die ("Unable to select :-(");

	$num = mysql_num_rows($res);
	if($num == 0)
		$returnString = '{"status":-1,"exception":"No such review request or request not approved."}';
	else
		$returnString = '{"status":0}';
 	mysql_close($hd);

	echo $returnString;
?>
