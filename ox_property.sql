CREATE TABLE IF NOT EXISTS `ox_property` (
  `name` VARCHAR(50) NOT NULL,
  `owner` INT(11),
  `permissions` TEXT NOT NULL DEFAULT '[]'
);
