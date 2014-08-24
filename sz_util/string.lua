-- Quick helper to tell if a string starts with a prefix
-- string, without all the sub/len mess-around-ery.
function string:startswith(pref)
	return self:sub(1, pref:len()) == pref
end

-- Quick helper to tell if a string ends with a suffix
-- string, without all the sub/len mess-around-ery.
function string:endswith(suff)
	return suff == "" or self:sub(-suff:len()) == suff
end
