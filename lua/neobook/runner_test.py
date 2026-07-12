import sys
import json
from jupyter_client import KernelManager

code_str = """







import matplotlib.pyplot as plt
plt.plot ([1,2,3], [3,2,1])
plt.show ()

"""

def run_code (code_str, connection_file = None):

	if connection_file:
		km = KernelManager (connection_file = connection_file)
	else:
		km = KernelManager ()
		km.start_kernel (stdout = sys.stderr, stderr = sys.stderr)

	kc = km.client ()
	kc.start_channels ()
	kc.wait_for_ready (timeout = 5)

	msg_id = kc.execute (code_str)

	while True:
		try:
			msg = kc.get_iopub_msg (timeout = 10)
			msg_type = msg['header']['msg_type']
			content = msg['content']
			
			match msg_type:
				case 'stream':
					print (json.dumps ({
						'name': content['name'],
						'output_type': msg_type,
						'text': [f'{text}\n' for text in content['text'].split ('\n') if text != '']
					}), flush = True)

				case 'display_data':
					print (json.dumps ({
						'output_type': msg_type,
						'data': {
							'text/plain': [content['data']['text/plain']],
							'image/png': content['data']['image/png']
							},
						'metadata': content['metadata']
					}), flush = True)

				case 'status':
					if content['execution_state'] == 'idle':
						break

				case _:
					# print ('some other case')
					pass

		except Exception:
			break
	
	kc.stop_channels ()
	if not connection_file:
		km.shutdown_kernel ()

if __name__ == '__main__':
	run_code (code_str)
