-- phpMyAdmin SQL Dump
-- version 3.4.6
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Dec 19, 2011 at 09:31 PM
-- Server version: 5.0.91
-- PHP Version: 5.3.8-pl0-gentoo

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `ritzmosql1`
--

-- --------------------------------------------------------

--
-- Table structure for table `codes`
--

CREATE TABLE IF NOT EXISTS `codes` (
  `uuid1` varchar(40) NOT NULL,
  `uuid2` varchar(40) NOT NULL,
  `uuid3` varchar(40) NOT NULL,
  `uuid4` varchar(40) NOT NULL,
  `uuid5` varchar(40) NOT NULL,
  `productid` varchar(100) character set latin1 collate latin1_general_cs NOT NULL,
  `code` varchar(6) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `requests`
--

CREATE TABLE IF NOT EXISTS `requests` (
  `udid` varchar(40) NOT NULL,
  `productid` varchar(100) NOT NULL,
  `email` varchar(100) default NULL,
  `message` varchar(1000) default NULL,
  `status` tinyint(1) NOT NULL default '0',
  `lastUpdated` timestamp NOT NULL default CURRENT_TIMESTAMP
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
