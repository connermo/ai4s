-- 为containers表添加container_uid和container_gid字段
ALTER TABLE containers 
ADD COLUMN container_uid INT NULL,
ADD COLUMN container_gid INT NULL;

-- 添加注释
ALTER TABLE containers 
MODIFY COLUMN container_uid INT NULL COMMENT '容器内用户的UID',
MODIFY COLUMN container_gid INT NULL COMMENT '容器内用户的GID'; 