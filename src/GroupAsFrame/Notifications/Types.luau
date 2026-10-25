--!nonstrict

export type Kind = "info" | "success" | "warning" | "error"

export type Notification = {
	id: number,
	text: string,
	kind: Kind,
	duration: number,
	-- Set when the notification should animate out on its own, such as when too many are open
	dismissed: boolean,
}

return nil
