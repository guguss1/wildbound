# Biomas — diseño de referencia (no todos para primera versión)
| Tier | Bioma | Paleta/clima | Criaturas | Guardián/amenaza | POI dinámico |
|---|---|---|---|---|---|
| 1 | Praderas y Bosque Vivo | Verde/ámbar; cielo claro, lluvia suave | Bestiales, vegetales | Imitador de arbustos | Árbol ancestral/guarida |
| 2 | Montañas Heladas | Azul/blanco; tormenta y huellas | Hielo, ancestrales | Yeti | Cueva helada |
| 3 | Tierras Volcánicas | Rojo/ocre; ceniza y géiseres | Fuego, mineral | Excavador de magma | Santuario de ceniza |
| 4 | Bosque de Niebla | Gris/verde; bruma intensa | Fúngicos, espectrales | Invisible de contorno | Refugio abandonado |
| 5 | Ruinas Crípticas | Violeta/piedra; silencio ritual | Ancestrales, sombra | Guardián de la mirada | Catacumba variable |
| 6 | Abismo Endemoniado | Carmesí/negro; tormenta sobrenatural | Infernal, vacío | Pastor de ecos | Fisura de anomalía |

- Terror no estrictamente lineal: excepciones raras en biomas bonitos, anunciadas por pistas.
- Cambios de clima por **región del jugador**, no modificar globalmente `Lighting` para todos de biomas distintos.
- Mundo legible y reconocible; 'procedural' aplica a la combinación de encuentros, estructuras modulares, entradas y refugios.
- Refugios no garantizados en la misma ubicación; validar que exista una ruta posible de salida al generar.
- En móvil usar instancia streaming, LOD/presets, partículas limitadas y culling de NPC distantes.
