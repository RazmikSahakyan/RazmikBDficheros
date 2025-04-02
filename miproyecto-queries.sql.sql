-- 1
select a.Id_Actor as IdActor, a.Nombre  as Nombre_Actor, a.Apellido  as ApellidoActor,
if (count(aap.pelicula_id_pelicula)=0, 'NO HA ACTUADO', count(aap.pelicula_id_pelicula)) as NumPeliculas 
from actor a left join actor_actua_pelicula aap 
on a.Id_Actor = aap.actor_Id_Actor 
group by a.Id_Actor, a.Nombre, a.Apellido 
order by NumPeliculas desc;


-- 2
select c.nombre_cine, s.id_sala, s.capacidad, s.tipo, c.Id_Cine 
from cine c inner join sala s 
on c.id_cine = s.cine_id_cine
    inner join proyeccion p 
    on s.id_sala = p.sala_id_sala
where  s.capacidad = (
        select max(s2.capacidad)
        from sala s2
        where s2.cine_id_cine = c.id_cine
        )
group by c.id_cine, c.nombre_cine, s.id_sala, s.capacidad, s.tipo, c.Id_Cine 
order by c.Id_Cine asc;


-- 3
select c.id_cine, c.nombre_cine, c.ciudad, avg(s.precio) as precio_promedio 
from cine c inner join sala s 
on c.id_cine = s.cine_id_cine 
group by c.id_cine, c.nombre_cine, c.ciudad 
order by precio_promedio desc;


-- 4
select concat(a.apellido, ' ', a.nombre) as nombre_completo, count(ap.pelicula_Id_Pelicula) as peliculas
from actor a
inner join actor_actua_pelicula ap on a.id_actor = ap.actor_id_actor
group by a.id_actor, a.apellido, a.nombre
having count(ap.pelicula_id_pelicula) < (
    select avg(peliculas_por_actor) 
    from (
        select count(*) as peliculas_por_actor
        from actor_actua_pelicula
        group by actor_id_actor
    ) as peliculas_por_actor
)
order by a.apellido;
-- Media de peliculas de un actor
select AVG(peliculas_por_actor) as promedio_peliculas_por_actor
from (
    select COUNT(*) AS peliculas_por_actor
    from actor_actua_pelicula
    group by actor_id_actor
) as media;



-- 5
select a.nombre, a.apellido, a.fecha_nacimiento, count(ap.pelicula_id_pelicula) as total_peliculas
from actor a left join actor_actua_pelicula ap 
on a.id_actor = ap.actor_id_actor
group by a.id_actor, a.nombre, a.apellido, a.fecha_nacimiento
having a.fecha_nacimiento <= all (
    select a2.fecha_nacimiento 
    from actor a2
)
order by total_peliculas asc;






-- VISTAS

-- 1
create view promedio_precios_cines as
select c.id_cine, c.nombre_cine, c.ciudad, avg(s.precio) as precio_promedio 
from cine c inner join sala s 
on c.id_cine = s.cine_id_cine 
group by c.id_cine, c.nombre_cine, c.ciudad 
order by precio_promedio desc;


-- 2
create view mayorCapacidadSala_cine as
select c.nombre_cine, s.id_sala, s.capacidad, s.tipo, c.Id_Cine 
from cine c inner join sala s 
on c.id_cine = s.cine_id_cine
    inner join proyeccion p 
    on s.id_sala = p.sala_id_sala
where  s.capacidad = (
        select max(s2.capacidad)
        from sala s2
        where s2.cine_id_cine = c.id_cine
        )
group by c.id_cine, c.nombre_cine, s.id_sala, s.capacidad, s.tipo, c.Id_Cine 
order by c.Id_Cine asc;






-- FUNCIONES

-- 1 
delimiter &&
create function contarproyeccionesporpelicula(p_id_pelicula int)
returns int
deterministic
begin
    declare conteo int;
    -- verificar si la película existe
    if not exists (select 1 from pelicula where id_pelicula = p_id_pelicula) then
        return -1; -- Muestra -1 si la película no existe
    end if;
    
    -- contar el número de proyecciones
    set conteo = (select count(*) 
                  from proyeccion 
                  inner join pelicula on proyeccion.pelicula_id_pelicula = pelicula.id_pelicula
                  where pelicula.id_pelicula = p_id_pelicula);
    
    return ifnull(conteo, 0);
end &&
delimiter ;


show function status where db = 'proyectocine' and name = 'contarproyeccionesporpelicula';

select contarproyeccionesporpelicula(342) as proyecciones;

-- 2
delimiter &&
create function resenaspositivasporpeliculahora(p_id_pelicula int)
returns int
deterministic
begin
    declare total int;
    -- Verificar si la película existe
    if not exists (select 1 from pelicula where id_pelicula = p_id_pelicula) then
        return -1; -- Muestra -1 si la película no existe
    end if;
    -- Contar reseñas positivas de las proyecciones a las 15:00
    set total = (select count(r.id_resena)
                 from resena r
                 inner join pelicula p on r.pelicula_id_pelicula = p.id_pelicula
                 inner join proyeccion pr on p.id_pelicula = pr.pelicula_id_pelicula
                 where r.puntuacion >= 7
                 and p.id_pelicula = p_id_pelicula
                 and pr.hora_proyeccion = '15:00');
    return ifnull(total, 0);
end &&
delimiter ;


show function status where db = 'proyectocine' and name = 'resenaspositivasporpeliculahora';


select resenaspositivasporpeliculahora(241) as resenas_positivas;





-- PROCEDIMIENTOS

-- 1. Muestra películas por cine.
delimiter &&
create procedure muestra_peliculas_por_cine(in p_id_cine int)
begin
    declare existe_cine int default 0;
    declare cantidad_peliculas int default 0;
    declare max_cines int default 25; -- Límite máximo de cines

    -- Verificar si el ID es negativo o mayor que el límite máximo
    if p_id_cine <= 0 or p_id_cine > max_cines then
        select CONCAT('ID de cine inválido. Debe estar entre 1 y ', max_cines) as Mensaje;
    else
        -- Verificar si el cine existe
        select count(*) into existe_cine from cine where id_cine = p_id_cine;
        if existe_cine > 0 then
            -- Contar la cantidad de películas en ese cine
            select count(distinct p.id_pelicula) into cantidad_peliculas
            from pelicula p
            inner join proyeccion pr on p.id_pelicula = pr.pelicula_id_pelicula
            inner join sala s on pr.sala_id_sala = s.id_sala and pr.sala_cine_id_cine = s.cine_id_cine
            where s.cine_id_cine = p_id_cine;

            if cantidad_peliculas > 0 then
                select distinct p.titulo as Pelicula
                from pelicula p
                inner join proyeccion pr on p.id_pelicula = pr.pelicula_id_pelicula
                inner join sala s on pr.sala_id_sala = s.id_sala and pr.sala_cine_id_cine = s.cine_id_cine
                where s.cine_id_cine = p_id_cine;
            else
                select 'Sin películas' as Mensaje;
            end if;
        end if;
    end if;
end &&
delimiter ;


call muestra_peliculas_por_cine(2);




-- 2. Elimina un actor
delimiter &&
create procedure eliminar_actor(in p_id_actor int)
begin
    declare existe_actor int default 0;
    declare tiene_peliculas int default 0;

    -- verificar si el actor existe
    select count(*) into existe_actor from actor where id_actor = p_id_actor;

    if existe_actor = 0 then
        select 'el actor no existe' as mensaje;
    else
        -- verificar si el actor está asociado a alguna película
        select count(*) into tiene_peliculas from actor_actua_pelicula where actor_id_actor = p_id_actor;

        if tiene_peliculas > 0 then
            -- eliminar relaciones del actor con películas antes de eliminarlo
            delete from actor_actua_pelicula where actor_id_actor = p_id_actor;
        end if;

        -- eliminar el actor
        delete from actor where id_actor = p_id_actor;

        -- confirmar eliminación verificando si el actor sigue existiendo
        select count(*) into existe_actor from actor where id_actor = p_id_actor;
        
        if existe_actor = 0 then
            select 'actor eliminado exitosamente' as mensaje;
        else
            select 'error al eliminar el actor' as mensaje;
        end if;
    end if;
end &&
delimiter ;


call eliminar_actor(1);



-- 3 Mostrar la cantidad de películas en las que ha actuado un actor por género

delimiter &&
create procedure contar_peliculas_por_actor_genero(in p_id_actor int)
begin
    declare existe_actor int default 0;
    
    -- Verificar si el actor existe
    select count(*) into existe_actor from actor where id_actor = p_id_actor;
    
    if existe_actor = 0 then
        select 'El actor no existe' as Mensaje;
    else
        -- Contar la cantidad de películas en las que ha actuado el actor por género
        select p.genero, count(distinct p.id_pelicula) as total_peliculas
        from pelicula p
        inner join actor_actua_pelicula ap on p.id_pelicula = ap.pelicula_id_pelicula
        where ap.actor_id_actor = p_id_actor
        group by p.genero;
    end if;
end &&
delimiter ;

call contar_peliculas_por_actor_genero(23);




-- TRIGGERS
DELIMITER &&

-- 1. Verificar que la duración de la película sea al menos 60 minutos
CREATE TRIGGER validar_duracion_pelicula
BEFORE INSERT ON pelicula
FOR EACH ROW
BEGIN
    IF NEW.Duracion < 60 THEN
        INSERT INTO Error_insert (mensaje, fecha_error)
        VALUES (CONCAT('Error: La película "', NEW.Titulo, '" tiene una duración de ', NEW.Duracion, ' minutos, debe ser al menos 60.'), NOW());
        SET NEW.Id_Pelicula = NULL;
    END IF;
END &&


INSERT INTO pelicula (Id_Pelicula, Titulo, Genero, Duracion, Sinopsis, Director, Anio_Lanzamiento)
VALUES (1, 'Película Corta', 'Comedia', 50, 'Una película demasiado corta', 'Director X', '2025-04-01');



-- 2. Verificar que el actor a insertar tenga menos de 100 años
DELIMITER &&
CREATE TRIGGER verificarEdadActorAntesInsertar
BEFORE INSERT ON actor
FOR EACH ROW
BEGIN
    DECLARE edad INT;
    SET edad = TIMESTAMPDIFF(YEAR, NEW.Fecha_Nacimiento, CURDATE());
    
    IF edad < 18 THEN
        INSERT INTO Error_insert (mensaje, fecha_error)
        VALUES (CONCAT('Error: El actor ', NEW.Nombre, ' ', NEW.Apellido, ' tiene ', edad, ' años y no cumple con la edad mínima de 18 años.'), NOW());
        SET NEW.Id_Actor = NULL; -- Evitar la inserción del actor
    END IF;
END &&
DELIMITER ;


CREATE TABLE IF NOT EXISTS `Error_insert` (
    `mensaje` VARCHAR(255),
    `fecha_error` DATETIME
);


INSERT INTO actor (Id_Actor, Nombre, Apellido, Fecha_Nacimiento)
VALUES (10000, 'Juan', 'Pérez', '2018-05-10');



