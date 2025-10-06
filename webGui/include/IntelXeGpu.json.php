<?php
header("Content-Type: application/json");
echo file_get_contents("http://127.0.0.1:9200/metrics");
?>
