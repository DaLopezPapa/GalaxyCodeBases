#include "ThreadManager.h"

pthread_mutex_t		mutex_ctrl = PTHREAD_MUTEX_INITIALIZER;

void* __processwork(void* p)                                   
{	THRPARAM*	param = (THRPARAM*)p;

	while(param->pMgr->m_nindex<param->pMgr->m_nmaxthread)
	{
		int		nindex = 0;
		pthread_mutex_lock(&mutex_ctrl);                            
		if(param->pMgr->m_nindex<param->pMgr->m_nmaxthread)          
		{
			nindex = param->pMgr->m_nindex++;	
		}
		else                                                        
		{
			pthread_mutex_unlock(&mutex_ctrl);
			break;
		}
		pthread_mutex_unlock(&mutex_ctrl);                            
		param->pMgr->m_vproc[nindex](param->pMgr->m_vparam[nindex]);
	}
}

ThreadManager::ThreadManager()
{
	m_nindex = 0;
	m_nmaxthread = 0;
	m_ftimer = 0.1;
	m_cpu = 1;
}

ThreadManager::ThreadManager( int cpu ):m_cpu(cpu)
{
	m_nindex = 0;
	m_nmaxthread = 0;
	m_ftimer = 0.5;

	if(m_cpu <= 0)m_cpu = 1;
}

ThreadManager::~ThreadManager()
{
	// UPDATE at 2010-10-21
	for (int i = 0; i < m_vparam.size(); ++i)
	{
		if (m_vparam[i] != NULL)
			delete m_vparam[i];
		m_vparam[i] = NULL;
	}
}

void ThreadManager::AddThread( pthreadproc pProc, void* param )
{
	m_vproc.push_back(pProc);
	m_vparam.push_back(param);
	m_nmaxthread++;
}

void ThreadManager::Run()
{
	if(m_cpu >= m_nmaxthread)m_cpu = m_nmaxthread;
	vector<pthread_t>	vid(m_cpu);
	vector<THRPARAM>	vparam(m_cpu);
	for (int i=0; i<m_cpu; i++)
	{
		vparam[i].pMgr = this;
		vparam[i].flag = 0;                                  
		pthread_create(&vid[i], NULL, __processwork, (void*)&vparam[i]);
		usleep(int(m_ftimer*float(1000000)));
	}

	for (int i=0; i<m_cpu; i++)
	{
		pthread_join(vid[i], NULL);
	}
}

void ThreadManager::SetTimer( float t /*= 0.5*/ )
{
	m_ftimer = t;	
}

void ThreadManager::Reset()
{
	m_ftimer = 1.0;
	m_cpu = 1;
	m_nmaxthread = 0;
	m_nindex = 0;

	// UPDATE at 2010-10-12
	for (int i = 0; i < m_vparam.size(); ++i)
	{
		delete m_vparam[i];
		m_vparam[i] = NULL;
	}
	m_vparam.clear();
	m_vproc.clear();
}

void ThreadManager::SetCPU( int count )
{
	m_cpu = count;
	if (m_cpu >= m_nmaxthread) m_cpu = m_nmaxthread;
}
