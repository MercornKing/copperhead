--!strict
-- Signal: minimal in-process event, used for server service-to-service notifications.

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { (T...) -> () } = {}
	local self = {}

	function self.Connect(_self: Signal<T...>, fn: (T...) -> ()): Connection
		table.insert(handlers, fn)
		local connection = {}
		function connection.Disconnect(_c: Connection)
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end
		return (connection :: any) :: Connection
	end

	function self.Fire(_self: Signal<T...>, ...: T...)
		for _, fn in table.clone(handlers) do
			task.spawn(fn, ...)
		end
	end

	return (self :: any) :: Signal<T...>
end

return Signal
