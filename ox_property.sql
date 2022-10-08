CREATE TABLE IF NOT EXISTS `ox_property` (
  `property` VARCHAR(50) NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `id` TINYINT(4) NOT NULL,
  `owner` VARCHAR(50) NOT NULL,
  `groups` TEXT NOT NULL DEFAULT '{}',
  `public` TINYINT(1) NOT NULL DEFAULT 0,
);
