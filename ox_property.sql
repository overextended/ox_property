CREATE TABLE IF NOT EXISTS `ox_property` (
  `name` VARCHAR(50) NOT NULL,
  `owner` INT(11) UNSIGNED,
  `group` VARCHAR(50),
  `permissions` TEXT NOT NULL DEFAULT '[{}]',
  INDEX `FK_ox_property_characters` (`owner`) USING BTREE,
  CONSTRAINT `FK_ox_property_characters` FOREIGN KEY (`owner`) REFERENCES `characters` (`charid`) ON UPDATE CASCADE ON DELETE SET NULL
);
