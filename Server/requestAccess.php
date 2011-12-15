<?php
require_once('config.php');

$prod = filter_input(INPUT_POST, 'productid', FILTER_SANITIZE_NUMBER_INT);
$udid = filter_input(INPUT_POST, 'udid', FILTER_SANITIZE_STRING);
$email = filter_input(INPUT_POST, 'email', FILTER_SANITIZE_EMAIL);
$message = filter_input(INPUT_POST, 'message', FILTER_SANITIZE_ENCODED);

// Connect to database server
$hd = mysql_connect($server, $loginsql, $passsql) or die ("Unable to connect");

// Select database
mysql_select_db ($dbname, $hd) or die ("Unable to select database");

$res = mysql_query("INSERT INTO requests(udid, productid, email, message) VALUES ('".mysql_real_escape_string($udid)."', '".mysql_real_escape_string($prod)."', '".mysql_real_escape_string($email)."', '".mysql_real_escape_string($message)."')",$hd)
	or die ("Unable to insert :-(");

mysql_close($hd);
 	
echo "Done!";
?>
