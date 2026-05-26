# templates.py

DESPIDO_IMPROCEDENTE_TEMPLATE = """# DEMANDA POR DESPIDO IMPROCEDENTE

**AL JUZGADO DE LO SOCIAL DE {ciudad} QUE POR TURNO DE REPARTO CORRESPONDA**

D. {nombre_trabajador}, mayor de edad, con D.N.I. nº {dni_trabajador}, y domicilio a efectos de notificaciones en {domicilio_trabajador}, ante este Juzgado comparezco y como mejor proceda en Derecho, **DIGO:**

Que por medio del presente escrito formulo **DEMANDA POR DESPIDO IMPROCEDENTE** contra la empresa {nombre_empresa}, con C.I.F. nº {cif_empresa} y domicilio social en {domicilio_empresa}, en base a los siguientes:

## HECHOS

1. **Relación Laboral**: Comencé a prestar mis servicios para la empresa demandada con fecha {fecha_inicio}, con la categoría profesional de {categoria_profesional} y percibiendo un salario diario de {salario_diario} € (incluida prorrata de pagas extraordinarias).
2. **Despido**: Con fecha {fecha_despido}, la empresa procedió a notificarme mi despido aduciendo las siguientes causas: {hechos}.
3. **Improcedencia**: La decisión extintiva de la empresa carece de toda justificación real, siendo los hechos imputados totalmente falsos/insuficientes, por lo que procede declarar la improcedencia del despido.
4. **Conciliación Previa**: Se ha celebrado el preceptivo acto de conciliación previa ante el SMAC con fecha {fecha_smac}, habiendo resultado el mismo con el resultado de {resultado_smac}.

## FUNDAMENTOS DE DERECHO

I. **Competencia**: Corresponde a los Juzgados de lo Social de conformidad con los artículos 1, 2.a) y 6 de la Ley Reguladora de la Jurisdicción Social (LRJS).
II. **Legitimación**: La ostenta el trabajador despedido en virtud del artículo 17 de la LRJS.
III. **Procedimiento**: El establecido en los artículos 103 y siguientes de la LRJS para el despido.
IV. **Fondo del Asunto**: Artículo 56 del Estatuto de los Trabajadores (ET) en relación con la declaración de improcedencia del despido y el devengo de la indemnización legal correspondiente de 33 días de salario por año de servicio (o prorrata correspondiente de 45 días por el tramo anterior a la reforma de 2012 si correspondiera).

Por todo lo expuesto,

**SUPLICO AL JUZGADO**: Que tenga por presentado este escrito, copias de este y documentos que se acompañan, admita a trámite la presente demanda por despido, y tras los trámites legales oportunos, dicte Sentencia por la que se declare la **IMPROCEDENCIA DEL DESPIDO**, condenando a la empresa demandada a que proceda a mi readmisión en las mismas condiciones anteriores al despido o, a su elección, a abonarme la indemnización legal de {indemnizacion_calculada} € correspondientes a los días legalmente tasados por año de servicio.

En {ciudad}, a {fecha_actual}."""

PAPELETA_CONCILIACION_TEMPLATE = """# PAPELETA DE CONCILIACIÓN PREVIA AL SMAC

**AL SERVICIO DE MEDIACIÓN, ARBITRAJE Y CONCILIACIÓN (SMAC) DE {provincia}**

D. {nombre_trabajador}, con D.N.I. nº {dni_trabajador}, y domicilio en {domicilio_trabajador}, comparezco ante este Servicio y como mejor proceda en Derecho, **DIGO:**

Que por medio de la presente papeleta formulo **SOLICITUD DE CELEBRACIÓN DE ACTO DE CONCILIACIÓN PREVIA** sobre **{motivo_conciliacion}** contra la empresa {nombre_empresa}, dedicada a la actividad de {actividad_empresa}, con domicilio en {domicilio_empresa}, de acuerdo con los siguientes:

## HECHOS

1. El solicitante viene prestando servicios para la empresa demandada desde el {fecha_inicio}, ostentando la categoría profesional de {categoria_profesional} y percibiendo un salario de {salario_mensual} € mensuales.
2. Que la presente reclamación se fundamenta en: {hechos}.
3. Que la empresa ha incurrido en un flagrante incumplimiento de sus obligaciones contractuales / legales al {detalle_incumplimiento}.

Por lo expuesto,

**SOLICITO**: Que tenga por presentada esta papeleta de conciliación previa, admita a trámite la misma, cite a las partes para la celebración de dicho acto en fecha y hora que se señale, y se consiga el avenimiento oportuno obligando a la empresa a readmitirme / abonarme la cantidad adeudada de {cantidad_reclamada} € en concepto de salarios pendientes.

En {provincia}, a {fecha_actual}."""

RECLAMACION_CANTIDAD_TEMPLATE = """# DEMANDA DE RECLAMACIÓN DE CANTIDAD

**AL JUZGADO DE LO SOCIAL DE {ciudad} QUE POR TURNO DE REPARTO CORRESPONDA**

D. {nombre_trabajador}, con D.N.I. nº {dni_trabajador}, ante este Juzgado comparezco y **DIGO:**

Que formulo **DEMANDA EN RECLAMACIÓN DE CANTIDAD** contra la empresa {nombre_empresa}, con domicilio en {domicilio_empresa}, fundamentada en los siguientes:

## HECHOS

1. **Relación Laboral**: Presto mis servicios desde {fecha_inicio} como {categoria_profesional} percibiendo un salario mensual de {salario_mensual} €.
2. **Deuda Devengada**: A la fecha de presentación de esta demanda, la empresa me adeuda la cantidad total de **{total_deuda} €**, desglosada en los siguientes conceptos salariales pendientes: {conceptos_deuda}.
3. **Reclamación Previa**: Se ha intentado el acto de conciliación previa obligatoria el pasado {fecha_smac} resultando SIN EFECTO / SIN AVENENCIA.

## FUNDAMENTOS DE DERECHO

I. Artículos 4.2.f) y 29 del Estatuto de los Trabajadores que consagran el derecho del trabajador a la percepción puntual de la remuneración pactada o legalmente establecida.
II. Artículo 82 y concordantes de la LRJS sobre el procedimiento ordinario de reclamación de cantidad.
III. Artículo 29.3 del ET que establece el interés por mora del 10% anual de lo adeudado.

Por lo expuesto,

**SUPLICO AL JUZGADO**: Que tenga por formalizada esta demanda, admita su trámite y condene a la demandada al abono de la suma reclamada de **{total_deuda} €**, más el 10% de interés por mora correspondiente de conformidad con el artículo 29.3 del ET.

En {ciudad}, a {fecha_actual}."""
