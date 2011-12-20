<?php
	require_once('config.php');
	header('Content-Type: text/plain'); 

	$returnString = '{"status":-1,"exception":"Unknown error."}';

	// Connect to database server and select database
	$con = mysql_connect($server, $loginsql, $passsql);
	if(!$con || !mysql_select_db($dbname, $con))
	{
		$returnString = '{"status":-1,"exception":"Unable to connect to database."}';
	}
	else
	{
		// first filter with php
		$prod = filter_input(INPUT_POST, 'productid', FILTER_SANITIZE_STRING);
		$code = strtolower(filter_input(INPUT_POST, 'code', FILTER_SANITIZE_STRING));
		$uuid = filter_input(INPUT_POST, 'uuid', FILTER_SANITIZE_STRING);

		// and now really make sure nothing hurts our database
		$prod = mysql_real_escape_string($prod);
		$code = mysql_real_escape_string($code);

		// execute query
		$res = mysql_query("SELECT * FROM codes WHERE LOWER(code)='$code' AND productid='$prod'", $con);

		if(!$res || mysql_num_rows($res) != 1)
			$returnString = '{"status":-1,"exception":"Invalid or no response from database."}';
		else
		{
			$row = mysql_fetch_array($res, MYSQL_ASSOC);
			$fields = array('uuid1', 'uuid2', 'uuid3', 'uuid4', 'uuid5');
			$success = 0; // 0 = no, set status - 1 = no, leave status - 2 = yes, set status
			foreach($fields AS $field)
			{
				if(empty($row[$field]))
				{
					// update table so it reads this value
					$uuid = mysql_real_escape_string($uuid);
					$res = mysql_query("UPDATE codes SET $field='$uuid' WHERE code='$code'", $con);
					if(mysql_affected_rows() != 1)
					{
						$returnString = '{"status":-1,"exception":"Unable to update database."}';
						$success = 1;
					}
					else
						$success = 2;
					break;
				}
				else if($row[$field] == $uuid)
				{
					// all is fine
					$success = 2;
				}
			}
			switch($success)
			{
				default:
				case 0:
					$returnString = '{"status":-1,"exception":"Code activation limit exceeded."}';
					break;
				case 1:
					break;
				case 2:
					$returnString = '{"status":0}';
					break;
			}
		}
		mysql_close($con);
	}
	echo $returnString;
?>
