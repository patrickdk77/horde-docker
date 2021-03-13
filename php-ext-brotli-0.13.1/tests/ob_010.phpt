--TEST--
brotli.output_compression ob_get_clean
--SKIPIF--
<?php
if (!extension_loaded('brotli')) die('skip');
if (version_compare(PHP_VERSION, '5.4.0', '<')) die('skip need version');
?>
--FILE--
<?php
ob_start(); echo "foo\n"; ob_get_clean();
if(!headers_sent()) ini_set('brotli.output_compression', true); echo "end\n";
?>
DONE
--EXPECT--
end
DONE
