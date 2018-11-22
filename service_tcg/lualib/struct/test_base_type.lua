local base_type =require "struct.base_type"
test=class(base_type)	-- 定义一个类 test 继承于 base_type
 
function test:ctor()	-- 定义 test 的构造函数
	print("test ctor")
end
 
function test:hello()	-- 重载 base_type:hello 为 test:hello
	print("hello test")
end

return test

-- a=test.new(1)	-- 输出两行，base_type ctor 和 test ctor 。这个对象被正确的构造了。
-- a:print_x()	-- 输出 1 ，这个是基类 base_type 中的成员函数。
-- a:hello()	-- 输出 hello test ，这个函数被重载了。