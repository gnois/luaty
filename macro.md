

Start with usage:

case!(x)
	when < 0
		return '-'
	when > 0
		return '+'
	return 0



ensure!(q ~= nil and not err)



---------------------------

macro case = \@, x, ... ->
	when:if  -- substitute when with if

	<= `if` x



macro ensure = \@, expr ->
	<= `if not ` expr
		`error(` false `, expr`)`
